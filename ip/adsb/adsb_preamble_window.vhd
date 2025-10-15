library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_preamble_window is
    generic (
        SAMPLES_PER_PULSEB     : positive;
        PREAMBLE_BUFFER_LENGTH : integer
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic; -- Clock enable.
        i_i : in iq_t;
        q_i : in iq_t;
        mag_sq_i : in mag_sq_t;

        i_o : out iq_t;
        q_o : out iq_t;
        mag_sq_o : out mag_sq_t;
        avg_carrier_o : out mag_sq_t;
        avg_noise_o : out mag_sq_t;
        win_inside_energy_o : out win_energy_t;
        win_outside_energy_o : out win_energy_t;
        all_thresholds_ok_o : out std_logic
    );
end adsb_preamble_window;

architecture rtl of adsb_preamble_window is
    -- How many samples the IQ stream is delayed by compared to when the preamble is detected.
    constant PIPELINE_DELAY : positive := 3;

    -- Where each pulse in the preamble starts.
    -- There are four pulses in the preamble of an ADS-B message.
    constant PREAMBLE_POSITION : adsb_int_array_t := (0, 2, 7, 9);

    -- Delay pipeline for IQ.
    -- The IQ buffer is for timing and is as long as the number of delay clock
    -- cycles of this component.
    signal i_buf_reg, q_buf_reg : iq_buffer_t(0 to PIPELINE_DELAY-1) := (others => (others => '0'));

    -- Taps.
    constant TAP_NOISE_FLOOR_LENGTH : integer := 2 ** integer(floor(log2(real(6*SAMPLES_PER_PULSEB - 1)))); -- L_M.
    constant TAP_CARRIER_LENGTH     : integer := 2 ** integer(floor(log2(real(SAMPLES_PER_PULSEB - 1)))); -- L_C.
    signal buf_tap_delay  : mag_sq_t;
    signal buf_tap_et_a   : mag_sq_t;
    signal buf_tap_et_b   : mag_sq_t;
    signal buf_tap_ew0_a  : mag_sq_t;
    signal buf_tap_ew0_b  : mag_sq_t;
    signal buf_tap_ew1_a  : mag_sq_t;
    signal buf_tap_ew1_b  : mag_sq_t;
    signal buf_tap_ew2_a  : mag_sq_t;
    signal buf_tap_ew2_b  : mag_sq_t;
    signal buf_tap_ew3_a  : mag_sq_t;
    signal buf_tap_ew3_b  : mag_sq_t;
    signal buf_tap_enf_a  : mag_sq_t;
    signal buf_tap_enf_b  : mag_sq_t;
    signal buf_tap_ec0_a  : mag_sq_t;
    signal buf_tap_ec0_b  : mag_sq_t;
    signal buf_tap_ec1_a  : mag_sq_t;
    signal buf_tap_ec1_b  : mag_sq_t;
    signal buf_tap_ec2_a  : mag_sq_t;
    signal buf_tap_ec2_b  : mag_sq_t;
    signal buf_tap_ec3_a  : mag_sq_t;
    signal buf_tap_ec3_b  : mag_sq_t;

    -- Rolling sums.
    constant SUM_NOISE_FLOOR_WIDTH : positive := gen_sum_width(IQ_MAG_SQ_WIDTH, TAP_NOISE_FLOOR_LENGTH);
    constant SUM_CARRIER_WIDTH : positive := gen_sum_width(IQ_MAG_SQ_WIDTH, TAP_CARRIER_LENGTH);
    constant SUM_BUFFER_WIDTH : positive := gen_sum_width(IQ_MAG_SQ_WIDTH, PREAMBLE_BUFFER_LENGTH);
    constant SUM_PULSEB_WIDTH : positive := gen_sum_width(IQ_MAG_SQ_WIDTH, SAMPLES_PER_PULSEB);
    signal rs_et_sum  : unsigned(SUM_BUFFER_WIDTH-1 downto 0);
    signal rs_ew0_sum : unsigned(SUM_PULSEB_WIDTH-1 downto 0);
    signal rs_ew1_sum : unsigned(SUM_PULSEB_WIDTH-1 downto 0);
    signal rs_ew2_sum : unsigned(SUM_PULSEB_WIDTH-1 downto 0);
    signal rs_ew3_sum : unsigned(SUM_PULSEB_WIDTH-1 downto 0);
    signal rs_enf_sum : unsigned(SUM_NOISE_FLOOR_WIDTH-1 downto 0);
    signal rs_ec0_sum : unsigned(SUM_CARRIER_WIDTH-1 downto 0);
    signal rs_ec1_sum : unsigned(SUM_CARRIER_WIDTH-1 downto 0);
    signal rs_ec2_sum : unsigned(SUM_CARRIER_WIDTH-1 downto 0);
    signal rs_ec3_sum : unsigned(SUM_CARRIER_WIDTH-1 downto 0);

    -- Accumulated buffer energy.
    subtype buffer_energy_t is unsigned(SUM_BUFFER_WIDTH-1 downto 0);

    -- Output registers.
    signal win_inside_energy_r : win_energy_t := (others => '0');
    signal win_outside_energy_r : win_energy_t := (others => '0');
    signal avg_mag_sq_carrier_r, avg_mag_sq_noise_floor_r : mag_sq_t := (others => '0');
    signal i_r, q_r : iq_t := (others => '0');
    signal mag_sq_r : unsigned(IQ_MAG_SQ_WIDTH-1 downto 0) := (others => '0');
    signal all_thresholds_ok_r : std_logic := '0';

begin
    u_adsb_tapped_buffer : entity work.adsb_tapped_buffer
        generic map (
            PREAMBLE_BUFFER_LENGTH => PREAMBLE_BUFFER_LENGTH,
            TAP_PIPELINE_DELAY     => PREAMBLE_BUFFER_LENGTH - PIPELINE_DELAY + 1,
            TAP_ET_B_POS           => 0,
            TAP_ET_A_POS           => PREAMBLE_BUFFER_LENGTH - 1,
            TAP_EW0_B_POS          => PREAMBLE_POSITION(0) * SAMPLES_PER_PULSEB,
            TAP_EW0_A_POS          => PREAMBLE_POSITION(0) * SAMPLES_PER_PULSEB + SAMPLES_PER_PULSEB - 1,
            TAP_EW1_B_POS          => PREAMBLE_POSITION(1) * SAMPLES_PER_PULSEB,
            TAP_EW1_A_POS          => PREAMBLE_POSITION(1) * SAMPLES_PER_PULSEB + SAMPLES_PER_PULSEB - 1,
            TAP_EW2_B_POS          => PREAMBLE_POSITION(2) * SAMPLES_PER_PULSEB,
            TAP_EW2_A_POS          => PREAMBLE_POSITION(2) * SAMPLES_PER_PULSEB + SAMPLES_PER_PULSEB - 1,
            TAP_EW3_B_POS          => PREAMBLE_POSITION(3) * SAMPLES_PER_PULSEB,
            TAP_EW3_A_POS          => PREAMBLE_POSITION(3) * SAMPLES_PER_PULSEB + SAMPLES_PER_PULSEB - 1,
            TAP_ENF_B_POS          => 13 * SAMPLES_PER_PULSEB - TAP_NOISE_FLOOR_LENGTH / 2,
            TAP_ENF_A_POS          => 13 * SAMPLES_PER_PULSEB - TAP_NOISE_FLOOR_LENGTH / 2 + TAP_NOISE_FLOOR_LENGTH - 1,
            TAP_EC0_B_POS          => PREAMBLE_POSITION(0) * SAMPLES_PER_PULSEB + (SAMPLES_PER_PULSEB - TAP_CARRIER_LENGTH) / 2,
            TAP_EC0_A_POS          => PREAMBLE_POSITION(0) * SAMPLES_PER_PULSEB + (SAMPLES_PER_PULSEB - TAP_CARRIER_LENGTH) / 2 + TAP_CARRIER_LENGTH - 1,
            TAP_EC1_B_POS          => PREAMBLE_POSITION(1) * SAMPLES_PER_PULSEB + (SAMPLES_PER_PULSEB - TAP_CARRIER_LENGTH) / 2,
            TAP_EC1_A_POS          => PREAMBLE_POSITION(1) * SAMPLES_PER_PULSEB + (SAMPLES_PER_PULSEB - TAP_CARRIER_LENGTH) / 2 + TAP_CARRIER_LENGTH - 1,
            TAP_EC2_B_POS          => PREAMBLE_POSITION(2) * SAMPLES_PER_PULSEB + (SAMPLES_PER_PULSEB - TAP_CARRIER_LENGTH) / 2,
            TAP_EC2_A_POS          => PREAMBLE_POSITION(2) * SAMPLES_PER_PULSEB + (SAMPLES_PER_PULSEB - TAP_CARRIER_LENGTH) / 2 + TAP_CARRIER_LENGTH - 1,
            TAP_EC3_B_POS          => PREAMBLE_POSITION(3) * SAMPLES_PER_PULSEB + (SAMPLES_PER_PULSEB - TAP_CARRIER_LENGTH) / 2,
            TAP_EC3_A_POS          => PREAMBLE_POSITION(3) * SAMPLES_PER_PULSEB + (SAMPLES_PER_PULSEB - TAP_CARRIER_LENGTH) / 2 + TAP_CARRIER_LENGTH - 1
        )
        port map (
            clk          => clk,
            ce_i         => ce_i,
            mag_sq_i     => mag_sq_i,
            tap_delay_o  => buf_tap_delay,
            tap_et_a_o   => buf_tap_et_a,
            tap_et_b_o   => buf_tap_et_b,
            tap_ew0_a_o  => buf_tap_ew0_a,
            tap_ew0_b_o  => buf_tap_ew0_b,
            tap_ew1_a_o  => buf_tap_ew1_a,
            tap_ew1_b_o  => buf_tap_ew1_b,
            tap_ew2_a_o  => buf_tap_ew2_a,
            tap_ew2_b_o  => buf_tap_ew2_b,
            tap_ew3_a_o  => buf_tap_ew3_a,
            tap_ew3_b_o  => buf_tap_ew3_b,
            tap_enf_a_o  => buf_tap_enf_a,
            tap_enf_b_o  => buf_tap_enf_b,
            tap_ec0_a_o  => buf_tap_ec0_a,
            tap_ec0_b_o  => buf_tap_ec0_b,
            tap_ec1_a_o  => buf_tap_ec1_a,
            tap_ec1_b_o  => buf_tap_ec1_b,
            tap_ec2_a_o  => buf_tap_ec2_a,
            tap_ec2_b_o  => buf_tap_ec2_b,
            tap_ec3_a_o  => buf_tap_ec3_a,
            tap_ec3_b_o  => buf_tap_ec3_b
        );


    u_adsb_rolling_sum_et : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_BUFFER_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_et_a,
            outgoing_i => buf_tap_et_b,
            sum_o      => rs_et_sum
        );

    u_adsb_rolling_sum_ew0 : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_PULSEB_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_ew0_a,
            outgoing_i => buf_tap_ew0_b,
            sum_o      => rs_ew0_sum
        );

    u_adsb_rolling_sum_ew1 : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_PULSEB_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_ew1_a,
            outgoing_i => buf_tap_ew1_b,
            sum_o      => rs_ew1_sum
        );

    u_adsb_rolling_sum_ew2 : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_PULSEB_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_ew2_a,
            outgoing_i => buf_tap_ew2_b,
            sum_o      => rs_ew2_sum
        );

    u_adsb_rolling_sum_ew3 : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_PULSEB_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_ew3_a,
            outgoing_i => buf_tap_ew3_b,
            sum_o      => rs_ew3_sum
        );

    u_adsb_rolling_sum_enf : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_NOISE_FLOOR_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_enf_a,
            outgoing_i => buf_tap_enf_b,
            sum_o      => rs_enf_sum
        );

    u_adsb_rolling_sum_ec0 : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_CARRIER_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_ec0_a,
            outgoing_i => buf_tap_ec0_b,
            sum_o      => rs_ec0_sum
        );

    u_adsb_rolling_sum_ec1 : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_CARRIER_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_ec1_a,
            outgoing_i => buf_tap_ec1_b,
            sum_o      => rs_ec1_sum
        );

    u_adsb_rolling_sum_ec2 : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_CARRIER_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_ec2_a,
            outgoing_i => buf_tap_ec2_b,
            sum_o      => rs_ec2_sum
        );

    u_adsb_rolling_sum_ec3 : entity work.adsb_rolling_sum
        generic map (
            SUM_WIDTH => SUM_CARRIER_WIDTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_i,
            incoming_i => buf_tap_ec3_a,
            outgoing_i => buf_tap_ec3_b,
            sum_o      => rs_ec3_sum
        );

    -- Combinatorial signals.
    i_o <= i_r;
    q_o <= q_r;
    mag_sq_o <= mag_sq_r;

    -- Drive output port from registers.
    win_inside_energy_o <= win_inside_energy_r;
    win_outside_energy_o <= win_outside_energy_r;
    avg_carrier_o <= avg_mag_sq_carrier_r;
    avg_noise_o <= avg_mag_sq_noise_floor_r;
    all_thresholds_ok_o <= all_thresholds_ok_r;

    window_energy_process : process(clk)
        variable inside_energy, outside_energy : unsigned(rs_et_sum'length-1 downto 0);
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                inside_energy := resize(rs_ew0_sum, inside_energy'length)
                               + resize(rs_ew1_sum, inside_energy'length)
                               + resize(rs_ew2_sum, inside_energy'length)
                               + resize(rs_ew3_sum, inside_energy'length);

                outside_energy := resize(rs_et_sum, outside_energy'length) - inside_energy;

                win_inside_energy_r <= shrink_right(inside_energy, win_energy_t'length);
                win_outside_energy_r <= shrink_right(outside_energy, win_energy_t'length);
            end if;
        end if;
    end process window_energy_process;

    balanced_energy_process : process(clk)
        variable ew_sum : unsigned(rs_ew0_sum'length-1 downto 0);
        variable all_thresholds_ok_v : std_logic := '0';
        variable threshold_v : buffer_energy_t := (others => '0');
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                all_thresholds_ok_v := '1';

                -- The threshold applies to all four preamble high symbols.
                -- The threshold is relative to total energy in the preamble buffer.
                -- Threshold should be slightly less than 1/4 of total energy to trigger a detection.
                -- Therefore, use multiplication followed by shift right by 4 to achieve 3/16.
                -- The threshold ensures that each high symbol is getting roughly equal amounts of energy spread across it.
                threshold_v := resize((rs_et_sum * to_unsigned(3, rs_et_sum'length+2)) srl 4, rs_et_sum'length);
                all_thresholds_ok_v := '1';
                for i in 0 to 3 loop
                    case i is
                        when 0 => ew_sum := rs_ew0_sum;
                        when 1 => ew_sum := rs_ew1_sum;
                        when 2 => ew_sum := rs_ew2_sum;
                        when 3 => ew_sum := rs_ew3_sum;
                        when others => ew_sum := (others => '0');
                    end case;
                    if resize(ew_sum, threshold_v'length) <= threshold_v then
                        all_thresholds_ok_v := '0';
                    end if;
                end loop;

                all_thresholds_ok_r <= all_thresholds_ok_v;
            end if;
        end if;
    end process balanced_energy_process;

    -- Threshold for each preamble high symbol.
    schmitt_trigger_thresholds_process : process(clk)
        constant TOTAL_CARRIER_SUM_WIDTH : positive := SUM_CARRIER_WIDTH + 2;
        variable total_carrier_sum_v : unsigned(TOTAL_CARRIER_SUM_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                total_carrier_sum_v := resize(rs_ec0_sum, total_carrier_sum_v'length)
                                     + resize(rs_ec1_sum, total_carrier_sum_v'length)
                                     + resize(rs_ec2_sum, total_carrier_sum_v'length)
                                     + resize(rs_ec3_sum, total_carrier_sum_v'length);

                avg_mag_sq_carrier_r <= shrink_right(total_carrier_sum_v, avg_mag_sq_carrier_r'length);
                avg_mag_sq_noise_floor_r <= shrink_right(rs_enf_sum, avg_mag_sq_noise_floor_r'length);
            end if;
        end if;
    end process schmitt_trigger_thresholds_process;

    -- Pass-through signals delayed against the pipeline delay.
    -- These signals are useful for keeping everything synchronised, since
    -- preamble detection introduces delay.
    delay_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- Append most recently arrived sample onto the end of the shift register.
                i_buf_reg(PIPELINE_DELAY-1) <= i_i;
                q_buf_reg(PIPELINE_DELAY-1) <= q_i;
                
                -- Pipeline shift registers for IQ and magnitude squared envelope.
                for i in 0 to PIPELINE_DELAY-2 loop
                    i_buf_reg(i) <= i_buf_reg(i+1);
                    q_buf_reg(i) <= q_buf_reg(i+1);
                end loop;

                i_r <= i_buf_reg(0);
                q_r <= q_buf_reg(0);
                mag_sq_r <= buf_tap_delay;
            end if;
        end if;
    end process delay_process;
end rtl;
