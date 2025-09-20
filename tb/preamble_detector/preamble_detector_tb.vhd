library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity preamble_detector_tb is
--  port ( );
    generic (runner_cfg : string);
end preamble_detector_tb;

architecture test of preamble_detector_tb is
    constant IQ_WIDTH : integer := 12;
    constant MAGNITUDE_WIDTH : integer := IQ_WIDTH * 2 + 1;

    -- UUT signals.
    signal ce_i             : std_logic := '0';
    signal i_i              : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal q_i              : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal detect_o         : std_logic;
    signal mag_sq_o         : unsigned(MAGNITUDE_WIDTH-1 downto 0);
    signal high_threshold_o : unsigned(MAGNITUDE_WIDTH-1 downto 0);
    signal low_threshold_o  : unsigned(MAGNITUDE_WIDTH-1 downto 0);
    signal i_o              : signed(IQ_WIDTH-1 downto 0);
    signal q_o              : signed(IQ_WIDTH-1 downto 0);

    -- Clock.
    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    -- Test status signals.
    signal end_of_test : boolean := false;
begin
    clk <= not clk after clk_period / 2;
    
    uut : entity work.preamble_detector
        port map (
            clk              => clk,
            ce_i             => '1',
            i_i              => i_i,
            q_i              => q_i,
            detect_o         => detect_o,
            mag_sq_o         => mag_sq_o,
            high_threshold_o => high_threshold_o,
            low_threshold_o  => low_threshold_o,
            i_o              => i_o,
            q_o              => q_o
        );

    
    stimulus_process : process
        file iq_file : text open read_mode is "tb/schmitt_trigger/iq_data.txt";
        variable line_buf : line;
        variable line_i, line_q : integer;
    begin
        test_runner_setup(runner, runner_cfg);
        report "Hello world!";
        while not endfile(iq_file) loop
          readline(iq_file, line_buf);
          read(line_buf, line_i);
          read(line_buf, line_q);
          
          i_i <= to_signed(line_i, 12);
          q_i <= to_signed(line_q, 12);
          
          wait for clk_period;
        end loop;

        -- End of test! Trigger checks!
        end_of_test <= true;
        wait for clk_period;
        
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process stimulus_process;

    verification_process : process(clk)
        variable done : boolean := false;
    begin
        if rising_edge(clk) then
            if end_of_test and not done then
                -- TODO Check data.
                --report "Did not receive all expected data." severity failure;
            end if;
        end if;
    end process verification_process;

    verify_synchronisation_process : process(clk)
        variable i_sq_v : signed(IQ_WIDTH*2-1 downto 0);
        variable q_sq_v : signed(IQ_WIDTH*2-1 downto 0);
        variable mag_sq_v : unsigned(MAGNITUDE_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            -- Ensure that IQ is synchronised with the envelope (magnitude squared.)
            i_sq_v := i_o * i_o;
            q_sq_v := q_o * q_o;
            mag_sq_v := resize(unsigned(i_sq_v), mag_sq_v'length) + resize(unsigned(q_sq_v), mag_sq_v'length);
            check_equal(mag_sq_o, mag_sq_v, "Magnitude squared mismatch. (Pipeline might be out of sync.)");
        end if;
    end process verify_synchronisation_process;
end test;
