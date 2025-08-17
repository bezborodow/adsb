library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;


entity ppm_demod_tb is
--  port ( );
    generic (runner_cfg : string);
end ppm_demod_tb;

architecture test of ppm_demod_tb is
    component ppm_demod is
        port (
            clk : in std_logic;
            ce : in std_logic;
            input : in std_logic;
            detect : in std_logic;
            valid : out std_logic;
            w56 : out std_logic;
            ready : in std_logic;
            malformed : out std_logic;
            data : out std_logic_vector(111 downto 0)
       );
    end component;

    signal clk : std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    signal ready : std_logic := '0';
    signal detect : std_logic := '1';
    signal input : std_logic := '0';
    signal valid : std_logic := '0';
    signal data : std_logic_vector(111 downto 0) := (others => '0');
    signal w56 : std_logic := '0';
    signal malformed : std_logic := '0';

    procedure send_frame(
        signal input_s : out std_logic;
        signal detect_S : out std_logic;
        frame_length : in integer
    ) is
    begin
        for i in 0 to frame_length/4 - 1 loop
            input_s <= '1';
            if i = 0 then
                detect_s <= '1';
                wait for clk_period;
                detect_s <= '0';
                wait for clk_period * 9;
            else
                detect_s <= '0';
                wait for clk_period * 10;
            end if;
            input_s <= '0';
            wait for clk_period * 10;

            input_s <= '0';
            wait for clk_period * 10;
            input_s <= '1';
            wait for clk_period * 10;

            input_s <= '0';
            wait for clk_period * 10;
            input_s <= '1';
            wait for clk_period * 10;

            input_s <= '1';
            wait for clk_period * 10;
            input_s <= '0';
            wait for clk_period * 10;
        end loop;

    end procedure send_frame;

begin
    clk <= not clk after clk_period / 2;

    uut: ppm_demod port map (
        ce => '1',
        clk => clk,
        ready => ready,
        input => input,
        detect => detect,
        valid => valid,
        data => data,
        w56 => w56,
        malformed => malformed
    );

    main : process
    begin
        test_runner_setup(runner, runner_cfg);

        if run("112bit") then
            send_frame(input, detect, 112);
            wait for clk_period * 50;
            assert valid = '1';
            ready <= '1';
            wait for clk_period;
            assert valid = '1';
            assert data = "1001100110011001100110011001100110011001100110011001100110011001100110011001100110011001100110011001100110011001" report "Data not as expected.";
            assert w56 = '0';
            assert malformed = '0';
            ready <= '0';
            wait for clk_period;
            assert valid = '0';
            assert unsigned(data) = 0;
            wait for clk_period * 50;
        end if;
        if run("56bit") then
            send_frame(input, detect, 56);
            wait for clk_period * 50;
            assert valid = '1';
            ready <= '1';
            wait for clk_period;
            assert valid = '1';
            assert data = "0000000000000000000000000000000000000000000000000000000010011001100110011001100110011001100110011001100110011001" report "Data not as expected.";
            assert w56 = '1';
            assert malformed = '0';
            ready <= '0';
            wait for clk_period;
            assert valid = '0';
            assert unsigned(data) = 0;
            wait for clk_period * 50;
        end if;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;
end test;
