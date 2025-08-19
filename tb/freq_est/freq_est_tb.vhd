library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;


entity freq_est_tb is
--  port ( );
    generic (runner_cfg : string);
end freq_est_tb;

architecture test of freq_est_tb is
    constant IQ_WIDTH : integer := 12;

    component freq_est is
        port (
            clk : in std_logic;
            en_i : in std_logic;
            i_i : in signed(IQ_WIDTH-1 downto 0);
            q_i : in signed(IQ_WIDTH-1 downto 0);
            gate_i : in std_logic;
            vld_o : out std_logic;
            rdy_i : in std_logic;
            freq_o : out signed(15 downto 0)
       );
    end component;

    signal clk : std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    signal en : std_logic := '0';
    signal i : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal q : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal gate : std_logic := '0';
    signal vld : std_logic := '0';
    signal rdy : std_logic := '0';
    signal freq : signed(15 downto 0) := (others => '0');

begin
    clk <= not clk after clk_period / 2;

    uut: freq_est port map (
        clk => clk,
        en_i => en,
        i_i => i,
        q_i => q,
        gate_i => gate,
        vld_o => vld,
        rdy_i => rdy,
        freq_o => freq
    );

    main : process
        file iq_file : text open read_mode is "tb/schmitt_trigger/iq_data.txt";
        variable line_buf : line;
        variable line_i, line_q : integer;
        variable input_i : signed(11 downto 0) := (others => '0');
        variable input_q : signed(11 downto 0) := (others => '0');
        variable magnitude_sq : unsigned(24 downto 0) := (others => '0');
    begin
        test_runner_setup(runner, runner_cfg);
        while not endfile(iq_file) loop
          readline(iq_file, line_buf);
          read(line_buf, line_i);
          read(line_buf, line_q);

          input_i := to_signed(line_i, 12);
          input_q := to_signed(line_q, 12);
          magnitude_sq := to_unsigned(
                  to_integer(input_i) * to_integer(input_i)
                + to_integer(input_q) * to_integer(input_q),
                magnitude_sq'length);
          gate <= '1' when magnitude_sq > 50000 else '0';
          i <= input_i;
          q <= input_q;

          wait for clk_period;
        end loop;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
