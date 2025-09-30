library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.math_real.uniform;

library vunit_lib;
context vunit_lib.vunit_context;


-- This test is designed to ensure that if the preamble detection is a few
-- cycles ahead or behind, then the PPM demodulator is robust enough to compensate.
-- There are several scenarios, with first bit 0, first bit 1, and with lead or lag
-- of the detect strobe.
entity ppm_demod_robust_tb is
--  port ( );
    generic (runner_cfg : string);
end ppm_demod_robust_tb;

architecture test of ppm_demod_robust_tb is
    signal clk : std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.

    constant SAMPLES_PER_SYMBOL : positive := 10;

    -- UUT (unit under test) signals.
    signal demod_ready : std_logic := '0';
    signal demod_detect : std_logic := '0';
    signal demod_envelope : std_logic := '0';
    signal demod_valid : std_logic := '0';
    signal demod_data : std_logic_vector(111 downto 0) := (others => '0');
    signal demod_w56 : std_logic := '0';
    signal demod_malformed : std_logic := '0';

    -- Test expected data.
    signal expected_data : std_logic_vector(111 downto 0);
    signal expected_w56 : std_logic := '0';

    -- The amount of offset for the detect strobe.
    -- The purpose of this test to is ensure that this can be out by roughly half the samples per symbols.
    signal detect_offset : integer := 0;

    -- Trigger the detect strobe and sending of test stimulus data to the UUT.
    signal trigger_tests : std_logic := '0';

    -- End of test; check that data was received!
    signal end_of_test : boolean := false;

    procedure send_bit(
        signal input_s : out std_logic;
        data_bit : in std_logic;
        variable seed1  : inout positive;
        variable seed2  : inout positive
    ) is
        variable symbols : std_logic_vector(1 downto 0) := "10";
        variable r : real;
        variable period1, period2 : integer;
    begin
        -- Pair of symbols based on data bit.
        --     '1' --> "10"
        --     '0' --> "01"
        if data_bit = '0' then
            symbols := "01";
        end if;

        -- Generate random periods 6..14.
        uniform(seed1, seed2, r);
        period1 := integer(6.0 + r * (14.0 - 6.0));

        uniform(seed1, seed2, r);
        period2 := integer(6.0 + r * (14.0 - 6.0));

        -- Send symbols.
        input_s <= symbols(0);
        wait for clk_period * period1;

        input_s <= symbols(1);
        wait for clk_period * period2;

    end procedure send_bit;

    procedure send_frame(
        signal input_s : out std_logic
    ) is
        variable seed1 : positive := 12345;
        variable seed2 : positive := 67890;
        variable i_start : natural := 0;
    begin
        i_start := 56 when expected_w56 = '1' else 0;

        for i in i_start to 111 loop
            send_bit(input_s, expected_data(i), seed1, seed2);
        end loop;
    end procedure send_frame;
begin
    clk <= not clk after clk_period / 2;

    uut : entity work.ppm_demod
        generic map (
            SAMPLES_PER_SYMBOL => SAMPLES_PER_SYMBOL
        )
        port map (
            clk => clk,
            ce_i => '1',
            rdy_i => demod_ready,
            envelope_i => demod_envelope,
            detect_i => demod_detect,
            vld_o => demod_valid,
            data_o => demod_data,
            w56_o => demod_w56,
            malformed_o => demod_malformed
        );

    main_test_process : process
    begin
        test_runner_setup(runner, runner_cfg);

        if run("112bit_msb1") then
            -- This begins with 0x8F, which has an MSB '1' bit.
            -- It should be easy to decode, not out of sync.
            expected_data <= x"8F7C776FF80300020049B8DAC606";
            expected_w56 <= '0';
            detect_offset <= 0;
        end if;
        if run("56bit_msb0") then
            expected_data <= x"000000000000005D7C431C41E265";
            expected_w56 <= '0';
            detect_offset <= 0;
        end if;

        if run("112bit_msb0_lead") then
            expected_data <= x"0F7C776FF80300020049B8DAC606";
            expected_w56 <= '0';
            detect_offset <= -4;
        end if;

        if run("112bit_msb0_lag") then
            expected_data <= x"0F7C776FF80300020049B8DAC606";
            expected_w56 <= '0';
            detect_offset <= 4;
        end if;

        if run("112bit_msb1_lead") then
            expected_data <= x"8D06A2B89909E8A3780807E6AEBF";
            expected_w56 <= '0';
            detect_offset <= -4;
        end if;

        if run("112bit_msb1_lag") then
            expected_data <= x"8F7C776FF80300020049B8DAC606";
            expected_w56 <= '0';
            detect_offset <= 4;
        end if;

        wait until rising_edge(clk);

        -- Trigger the detect strobe with an offset.
        trigger_tests <= '1';
        wait until rising_edge(clk);

        trigger_tests <= '0';
        wait until rising_edge(clk);
        
        -- Wait to get in time with the detect strobe.
        wait for clk_period * SAMPLES_PER_SYMBOL;

        -- Send the data.
        send_frame(demod_envelope);

        -- Bit of extra time.
        wait for clk_period * 5;

        -- End of test! Trigger checks!
        end_of_test <= true;
        wait for clk_period;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main_test_process;

    stimulus_detect_strobe_process : process(clk)
        variable counter : natural := 0;
        variable send_detect : boolean := false;
    begin
        if rising_edge(clk) then
            if trigger_tests = '1' then
                send_detect := true;
            end if;

            if send_detect then
                if counter = SAMPLES_PER_SYMBOL + detect_offset then
                    demod_detect <= '1'; 
                else
                    demod_detect <= '0'; 
                end if;
                counter := counter + 1;
            end if;
        end if;
    end process stimulus_detect_strobe_process;

    -- This process will check that the ADS-B message is demodulated.
    verification_process : process(clk)
        -- When found the detect signal in the correct place.
        variable done : boolean := false;
    begin
        if rising_edge(clk) then
            if demod_valid = '1' and demod_ready = '0' then
                demod_ready <= '1';

                check_equal(expected_data, demod_data, "Demodulated data not as expected.");
                check_equal(expected_w56, demod_w56, "Demodulated data frame length not as expected.");
                done := true;
            end if;

            if demod_ready = '1' and demod_valid = '1' then
                demod_ready <= '0';
            end if;

            --  Check done.
            if end_of_test and not done then
                report "Did not demodulate the message." severity failure;
            end if;
        end if;
    end process verification_process;
end test;
