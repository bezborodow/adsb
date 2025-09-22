library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
library vunit_lib;
context vunit_lib.vunit_context;

entity adsb_tb is
--  port ( );
    generic (runner_cfg : string);
end adsb_tb;

architecture test of adsb_tb is
    signal input_i : signed(11 downto 0) := (others => '0');
    signal input_q : signed(11 downto 0) := (others => '0');

    signal clk: std_logic := '1';
    constant clk_period : time := 50 ns; -- 20 MHz sample rate.
    signal end_of_test : boolean := false;

    signal adsb_detect : std_logic := '0';
    signal adsb_vld : std_logic := '0';
    signal adsb_rdy : std_logic := '0';
    signal adsb_data : std_logic_vector(111 downto 0) := (others =>'0');
    signal adsb_w56 : std_logic := '0';

begin
    clk <= not clk after clk_period / 2;

    uut : entity work.adsb
        generic map (
            SAMPLES_PER_SYMBOL     => 20,
            PREAMBLE_BUFFER_LENGTH => 320,
            ACCUMULATION_LENGTH    => 2048
        )
        port map (
            clk => clk,
            d_vld_i => '1',
            i_i => input_i,
            q_i => input_q,
            detect_o => adsb_detect,
            vld_o => adsb_vld,
            rdy_i => adsb_rdy,
            data_o => adsb_data,
            w56_o => adsb_w56
        );

    main : process
        file iq_file : text open read_mode is "tb/data/gen/adsb_capture_40_000_000_hertz.dat";
        variable line_buf : line;
        variable line_i, line_q : integer;
    begin
        test_runner_setup(runner, runner_cfg);
        report "Hello world!";
        while not endfile(iq_file) loop
            readline(iq_file, line_buf);
            read(line_buf, line_i);
            read(line_buf, line_q);

            input_i <= to_signed(line_i, 12);
            input_q <= to_signed(line_q, 12);

            wait for clk_period;
        end loop;

        -- End of test! Trigger checks!
        end_of_test <= true;
        wait for clk_period * 2;

        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process main;

    -- This process will check for valid ADS-B data.
    verification_process : process(clk)
        -- Done when found valid ADS-B data.
        constant expected_message : std_logic_vector(111 downto 0) := x"8D7C79B46915452064F7B51A9D3A";
        variable preamble_detected : boolean := false;
        variable valid_message : boolean := false;
        variable done : boolean := false;
    begin
        if rising_edge(clk) then
            -- Check for preamble detection.
            if adsb_detect = '1' then
                if preamble_detected then
                    report "Only expect a preamble detection once!" severity failure;
                end if;
                preamble_detected := true;
            end if;

            -- Wait for valid message.
            if preamble_detected and adsb_vld = '1' then

                -- Check ADS-B message.
                report "ADS-B Message: " & to_hstring(adsb_data);
                check_equal(adsb_data, expected_message, "ADS-B message mismatch.");
                assert adsb_w56 = '0' report "Expected 112 bits, so w56 should be low." severity failure;
                valid_message := true;

                -- Valid/ready handshake; ready high.
                adsb_rdy <= '1';
            end if;

            -- Check that valid flag is lowered after the handshake.
            if valid_message and adsb_vld = '0' then
                done := true;
                adsb_rdy <= '0';
            end if;

            --  Check done.
            if end_of_test and not preamble_detected then
                report "Did not detect the ADS-B preamble." severity failure;
            end if;
            if end_of_test and not valid_message then
                report "Did not demodulate the ADS-B message." severity failure;
            end if;
            if end_of_test and not done then
                report "The valid flag was not lowered after asserting ready." severity failure;
            end if;
        end if;
    end process verification_process;
end test;
