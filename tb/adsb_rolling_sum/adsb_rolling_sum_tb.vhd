library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.all;
library vunit_lib;
context vunit_lib.vunit_context;
use work.adsb_pkg.all;

entity adsb_rolling_sum_tb is
    generic (runner_cfg : string);
end adsb_rolling_sum_tb;

architecture test of adsb_rolling_sum_tb is
    -- Clock.
    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    -- UUT generics.
    constant ROLLING_BUFFER_LENGTH : integer := 4;
    constant SUM_WIDTH             : integer := gen_sum_width(IQ_MAG_SQ_WIDTH, ROLLING_BUFFER_LENGTH);

    -- UUT signals.
    signal ce_i                  : std_logic := '1';
    signal incoming_i            : mag_sq_t := (others => '0');
    signal outgoing_i            : mag_sq_t := (others => '0');
    signal sum_o                 : unsigned(SUM_WIDTH-1 downto 0) := (others => '0');

    -- Test signals.
    signal incoming_z0           : mag_sq_t := (others => '0');
    signal incoming_z1           : mag_sq_t := (others => '0');
    signal incoming_z2           : mag_sq_t := (others => '0');
    signal incoming_z3           : mag_sq_t := (others => '0');
begin
    clk <= not clk after clk_period / 2;

    uut : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => incoming_i,
            outgoing_i => outgoing_i,
            sum_o      => sum_o
        );

    stimulus : process
        type primes_t is array(0 to 20) of integer;
        constant primes : primes_t := (0, 0, 0, 0, 0, 0, 0, 2, 3, 5, 7, 11, 13, 17, 0, 0, 0, 0, 0, 0, 0);
        variable buf_idx : integer := 0;
        variable expected_sum_v : unsigned(SUM_WIDTH-1 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        wait until rising_edge(clk);

        while buf_idx <= primes'high loop
            -- incoming: current buffer value (or zero if out of range)
            if buf_idx <= primes'high then
                incoming_i <= to_unsigned(primes(buf_idx), IQ_MAG_SQ_WIDTH);
            else
                incoming_i <= (others => '0');
            end if;

            -- outgoing: value delayed by ROLLING_BUFFER_LENGTH, else zero
            if buf_idx >= ROLLING_BUFFER_LENGTH then
                outgoing_i <= to_unsigned(primes(buf_idx - ROLLING_BUFFER_LENGTH), IQ_MAG_SQ_WIDTH);
            else
                outgoing_i <= (others => '0');
            end if;

            -- present values to UUT on next rising edge
            wait until rising_edge(clk);
            buf_idx := buf_idx + 1;

            -- Check expected sum.
            expected_sum_v := resize(unsigned(incoming_z0), SUM_WIDTH)
                            + resize(unsigned(incoming_z1), SUM_WIDTH)
                            + resize(unsigned(incoming_z2), SUM_WIDTH)
                            + resize(unsigned(incoming_z3), SUM_WIDTH);
            check_equal(sum_o, expected_sum_v, "Mismatched summation.");

            incoming_z0 <= incoming_i;
            incoming_z1 <= incoming_z0;
            incoming_z2 <= incoming_z1;
            incoming_z3 <= incoming_z2;
        end loop;

        -- Finish simulation.
        wait for 10 * clk_period;
        test_runner_cleanup(runner); -- Simulation ends here.
        wait;
    end process stimulus;

end test;
