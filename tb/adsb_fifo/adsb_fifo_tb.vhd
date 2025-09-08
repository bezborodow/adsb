library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity adsb_fifo_tb is
--  port ( );
    generic (runner_cfg : string);
end adsb_fifo_tb;

architecture test of adsb_fifo_tb is
    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.
    signal end_of_test : boolean := false;

    -- FIFO parameters.
    constant FIFO_WIDTH : integer := 16;
    constant FIFO_DEPTH : integer := 4;

    -- Clock and reset.
    signal fifo_clk : std_logic := '0';
    signal fifo_rst : std_logic := '0';

    -- Write side.
    signal fifo_wr_data  : std_logic_vector(FIFO_WIDTH-1 downto 0) := (others => '0');
    signal fifo_wr_vld   : std_logic := '0';
    signal fifo_wr_rdy   : std_logic;

    -- Read side.
    signal fifo_rd_data  : std_logic_vector(FIFO_WIDTH-1 downto 0);
    signal fifo_rd_vld   : std_logic := '0';
    signal fifo_rd_rdy   : std_logic := '0';

    -- Debug signals.
    signal fifo_full     : std_logic;
    signal fifo_empty    : std_logic;

    -- Data to send.
    type byte2_array_t is array (natural range <>) of std_logic_vector(FIFO_WIDTH-1 downto 0);
    constant expected_data : byte2_array_t(0 to 23) := (
        0  => x"1A2B",
        1  => x"3C4D",
        2  => x"5E6F",
        3  => x"7890",
        4  => x"ABCD",
        5  => x"EF01",
        6  => x"2345",
        7  => x"6789",
        8  => x"9ABC",
        9  => x"DEF0",
        10 => x"1357",
        11 => x"2468",
        12 => x"0F1E",
        13 => x"2D3C",
        14 => x"4B5A",
        15 => x"6978",
        16 => x"8F9E",
        17 => x"A1B2",
        18 => x"C3D4",
        19 => x"E5F6",
        20 => x"1020",
        21 => x"3040",
        22 => x"5060",
        23 => x"7080"
    );

    function slv16_to_hex(slv : std_logic_vector(15 downto 0)) return string is
        variable result : string(1 to 4);
        variable val : integer := to_integer(unsigned(slv));
        variable nibble : integer;
    begin
        for i in 1 to 4 loop
            nibble := (val / (16**(4-i))) mod 16;
            if nibble < 10 then
                result(i) := character'val(48 + nibble);  -- '0'..'9'
            else
                result(i) := character'val(55 + nibble);  -- 'A'..'F'
            end if;
        end loop;
        return result;
    end function;


begin
    clk <= not clk after clk_period / 2;

    uut : entity work.adsb_fifo
        generic map (
            FIFO_WIDTH => FIFO_WIDTH,
            FIFO_DEPTH => FIFO_DEPTH
        )
        port map (
            clk        => clk,
            rst        => fifo_rst,

            -- Write side.
            wr_data_i  => fifo_wr_data,
            wr_vld_i   => fifo_wr_vld,
            wr_rdy_o   => fifo_wr_rdy,

            -- Read side.
            rd_data_o  => fifo_rd_data,
            rd_vld_o   => fifo_rd_vld,
            rd_rdy_i   => fifo_rd_rdy,

            -- Debug signals.
            full_o     => fifo_full,
            empty_o    => fifo_empty
        );

    main_test_process : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for clk_period * 400;

        -- End of test! Trigger checks!
        end_of_test <= true;
        wait for clk_period;
        test_runner_cleanup(runner); -- Simulation ends here.
        wait;
    end process main_test_process;

    stimulus_process : process(clk)
        variable counter : natural := 0;
    begin
        if rising_edge(clk) then
            if counter < expected_data'length-1 then
                fifo_wr_data <= expected_data(counter);
                fifo_wr_vld <= '1';
                if fifo_wr_vld = '1' and fifo_wr_rdy = '1' then
                    counter := counter + 1; -- Advance only when write accepted.
                    fifo_wr_data <= expected_data(counter);
                end if;
            else
                fifo_wr_vld <= '0'; -- Stop writing when done.
                fifo_wr_data <= (others => '0');
            end if;
        end if;
    end process stimulus_process;

    verification_process : process(clk)
        variable done : boolean := false;
        variable counter : natural := 0;
        variable throttle : std_logic := '0';
        variable pause : natural := 0;
    begin
        if rising_edge(clk) then
            pause := pause + 1;
            if (pause > 20) then
                throttle := not throttle; -- Throttle the clock by half.
                if counter > 12 then
                    throttle := '1'; -- Change to full-speed up halfway through the test (full throttle.)
                end if;
                if throttle = '1' and fifo_rd_vld = '1' and not done then
                    fifo_rd_rdy <= '1';
                else
                    fifo_rd_rdy <= '0';
                end if;

                if fifo_rd_vld = '1' and fifo_rd_rdy = '1' then
                    assert fifo_rd_data = expected_data(counter)
                    report "Mismatch: expected=" & slv16_to_hex(expected_data(counter)) & " got=" & slv16_to_hex(fifo_rd_data)
                    severity failure;

                    counter := counter + 1;
                    if counter = expected_data'length then
                        done := true;
                    end if;
                end if;

                if end_of_test and not done then
                    report "Did not receive all expected data." severity failure;
                end if;
            end if;
        end if;
    end process verification_process;
end test;
