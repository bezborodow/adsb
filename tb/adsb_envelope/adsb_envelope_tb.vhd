library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity adsb_envelope_tb is
--  port ( );
    generic (runner_cfg : string);
end adsb_envelope_tb;

architecture test of adsb_envelope_tb is

    constant IQ_WIDTH : integer := 12;
    constant MAG_SQ_WIDTH : integer := IQ_WIDTH * 2 + 1;
    constant PIPELINE_DELAY : positive := 4;

    signal ce_i      : std_logic := '1';
    signal i_i, q_i  : signed(IQ_WIDTH-1 downto 0) := (others => '0');
    signal mag_sq_o  : unsigned(MAG_SQ_WIDTH-1 downto 0);
    signal i_o, q_o  : signed(IQ_WIDTH-1 downto 0);

    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.adsb_envelope
        generic map (
            IQ_WIDTH        => IQ_WIDTH,
            MAGNITUDE_WIDTH => MAG_SQ_WIDTH
        )
        port map (
            clk      => clk,
            ce_i     => ce_i,
            i_i      => i_i,
            q_i      => q_i,
            mag_sq_o => mag_sq_o,
            i_o      => i_o,
            q_o      => q_o
        );
    
    main_test_process : process
    begin
        test_runner_setup(runner, runner_cfg);

        wait until rising_edge(clk);

        -- Drive a known input.
        i_i <= to_signed(4, i_i'length);
        q_i <= to_signed(5, q_i'length);
        wait until rising_edge(clk);

        -- Set input back to zero.
        i_i <= to_signed(0, i_i'length);
        q_i <= to_signed(0, q_i'length);
        check_equal(i_o, to_signed(0, i_o'length), "I output mismatch.");
        check_equal(q_o, to_signed(0, q_o'length), "Q output mismatch.");
        check_equal(mag_sq_o, to_unsigned(0, mag_sq_o'length), "Magnitude squared mismatch.");
        wait until rising_edge(clk);

        -- Wait for the latency.
        for i in 1 to PIPELINE_DELAY loop
            check_equal(i_o, to_signed(0, i_o'length), "I output mismatch.");
            check_equal(q_o, to_signed(0, q_o'length), "Q output mismatch.");
            check_equal(mag_sq_o, to_unsigned(0, mag_sq_o'length), "Magnitude squared mismatch.");
            wait until rising_edge(clk);
        end loop;

        -- Check that outputs are correct and synchronised.
        check_equal(i_o, to_signed(4, i_o'length), "I output mismatch.");
        check_equal(q_o, to_signed(5, q_o'length), "Q output mismatch.");
        check_equal(mag_sq_o, to_unsigned(41, mag_sq_o'length), "Magnitude squared mismatch.");
        wait until rising_edge(clk);

        -- Check that outputs return to zero after pipeline.
        check_equal(i_o, to_signed(0, i_o'length), "I output mismatch.");
        check_equal(q_o, to_signed(0, q_o'length), "Q output mismatch.");
        check_equal(mag_sq_o, to_unsigned(0, mag_sq_o'length), "Magnitude squared mismatch.");
        wait until rising_edge(clk);

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main_test_process;
end test;
