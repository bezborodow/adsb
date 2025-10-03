library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

-- Frequency Estimator
entity freq_est is
    generic (
        ACCUMULATION_LENGTH : positive
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic;
        i_i : in iq_t;
        q_i : in iq_t;
        gate_i : in std_logic;
        start_i : in std_logic;
        stop_i : in std_logic;
        vld_o : out std_logic;
        rdy_i : in std_logic;
        est_re_o : out signed(31 downto 0);
        est_im_o : out signed(31 downto 0);
        enabled_o : out std_logic
    );
end freq_est;

architecture rtl of freq_est is
    constant ACCUMULATOR_WIDTH : positive := IQ_MAG_SQ_WIDTH + integer(ceil(log2(real(ACCUMULATION_LENGTH))));

    -- Phasor subtypes.
    constant PHASOR_WIDTH : positive := IQ_WIDTH * 2 + 1;
    subtype phasor_t is signed(PHASOR_WIDTH-1 downto 0);

    -- Input IQ data.
    signal i_z0, i_z1 : iq_t := (others => '0');
    signal q_z0, q_z1 : iq_t := (others => '0');

    -- Input gating from the Schmitt trigger.
    signal gate_z0, gate_z1 : std_logic := '0';

    -- Phasor calculation.
    signal ph_re0, ph_re1, ph_re0_z1, ph_re1_z1 : signed(IQ_WIDTH*2-1 downto 0) := (others => '0');
    signal ph_im0, ph_im1, ph_im0_z1, ph_im1_z1 : signed(IQ_WIDTH*2-1 downto 0) := (others => '0');

    -- Phasor real and imaginary parts.
    signal phasor_re : phasor_t := (others => '0');
    signal phasor_im : phasor_t := (others => '0');

    -- Phasor accumulator.
    signal accumulator_re : signed(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
    signal accumulator_im : signed(ACCUMULATOR_WIDTH-1 downto 0) := (others => '0');
    signal accumulation_count, ac_z1, ac_z2 : unsigned(integer(ceil(log2(real(ACCUMULATION_LENGTH))))-1 downto 0) := (others => '0');

    -- Enable flag, and delayed enabled flag for pipeline.
    signal enable, enable_z1, enable_z2, enable_z3 : std_logic := '0';

    -- Output registers.
    signal vld_r : std_logic := '0';
    signal est_re_r : signed(31 downto 0) := (others => '0');
    signal est_im_r : signed(31 downto 0) := (others => '0');

begin
    -- Drive outputs with registers.
    vld_o <= vld_r;
    est_re_o <= est_re_r;
    est_im_o <= est_im_r;
    enabled_o <= enable;

    -- Delayed signals.
    delay_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- To use a pipeline register before the DSP there is a need
                -- to register the input as z0 and.
                -- z1 is then also required for the x[n-1] sample.
                i_z0 <= i_i;
                q_z0 <= q_i;
                gate_z0 <= gate_i;
                i_z1 <= i_z0;
                q_z1 <= q_z0;
                gate_z1 <= gate_z0;
            end if;
        end if;
    end process delay_process;

    -- Accumulate phasors.
    accumulate_process : process(clk)
        procedure reset_procedure is
        begin
            accumulator_re <= (others => '0');
            accumulator_im <= (others => '0');
            accumulation_count <= (others => '0');
            enable <= '0';
            enable_z1 <= '0';
            enable_z2 <= '0';
            enable_z3 <= '0';
            vld_r <= '0';
        end procedure reset_procedure;

        variable accumulator_full : boolean := true;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- Reset on start.
                if start_i = '1' then
                    reset_procedure;
                    enable <= '1';
                end if;

                -- Check if accumulation count is less than the accumulation length.
                accumulator_full := to_integer(accumulation_count) = ACCUMULATION_LENGTH - 1;

                -- Stage 1: Multiplication.
                if (gate_i = '1') and (gate_z1 = '1') and (enable = '1') and not accumulator_full then
                    ph_re0 <= i_z0 * i_z1;
                    ph_re1 <= q_z0 * q_z1;
                    ph_im0 <= q_z0 * i_z1;
                    ph_im1 <= -i_z0 * q_z1;
                    enable_z1 <= '1';
                else
                    ph_re0 <= (others => '0');
                    ph_re1 <= (others => '0');
                    ph_im0 <= (others => '0');
                    ph_im1 <= (others => '0');
                    enable_z1 <= '0';
                end if;

                -- Stage 2: DSP pipeline register after the DSP.
                ph_re0_z1 <= ph_re0;
                ph_re1_z1 <= ph_re1;
                ph_im0_z1 <= ph_im0;
                ph_im1_z1 <= ph_im1;
                enable_z2 <= enable_z1;

                -- Stage 4: Addition.
                if enable_z2 = '1' then
                    phasor_re <= resize(ph_re0_z1 + ph_re1_z1, phasor_re'length);
                    phasor_im <= resize(ph_im0_z1 + ph_im1_z1, phasor_im'length);
                else
                    phasor_re <= (others => '0');
                    phasor_im <= (others => '0');
                end if;
                enable_z3 <= enable_z2;

                -- Stage 5: Accumulate the phasors.
                if enable_z3 = '1' then
                    accumulator_re <= accumulator_re + resize(phasor_re, accumulator_re'length);
                    accumulator_im <= accumulator_im + resize(phasor_im, accumulator_im'length);
                    accumulation_count <= accumulation_count + 1;
                end if;

                -- Stop when accumulator is full or upon external stop signal.
                if accumulator_full or stop_i = '1' then
                    if enable = '1' and accumulation_count > 0 then
                        -- Resize to a smaller complex number.
                        est_re_r <= shrink_right(accumulator_re, est_re_r'length);
                        est_im_r <= shrink_right(accumulator_im, est_im_r'length);
                        vld_r <= '1';
                    end if;

                    -- Halt the entire pipeline.
                    enable <= '0';
                    enable_z1 <= '0';
                    enable_z2 <= '0';
                    enable_z3 <= '0';
                end if;

                -- Reset when data has been read.
                if vld_r = '1' and rdy_i = '1' then
                    reset_procedure;
                end if;
            end if;
        end if;
    end process accumulate_process;
end rtl;
