library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_tapped_buffer is
    generic (
        PREAMBLE_BUFFER_LENGTH : integer;
        TAP_PIPELINE_DELAY     : integer;
        TAP_ET_A_POS           : integer;
        TAP_ET_B_POS           : integer;
        TAP_EW0_A_POS          : integer;
        TAP_EW0_B_POS          : integer;
        TAP_EW1_A_POS          : integer;
        TAP_EW1_B_POS          : integer;
        TAP_EW2_A_POS          : integer;
        TAP_EW2_B_POS          : integer;
        TAP_EW3_A_POS          : integer;
        TAP_EW3_B_POS          : integer;
        TAP_ENF_A_POS          : integer;
        TAP_ENF_B_POS          : integer;
        TAP_EC0_A_POS          : integer;
        TAP_EC0_B_POS          : integer;
        TAP_EC1_A_POS          : integer;
        TAP_EC1_B_POS          : integer;
        TAP_EC2_A_POS          : integer;
        TAP_EC2_B_POS          : integer;
        TAP_EC3_A_POS          : integer;
        TAP_EC3_B_POS          : integer
    );
    port (
        clk        : in  std_logic;
        ce_i       : in  std_logic;  -- Clock enable.
        mag_sq_i   : in  mag_sq_t;

        -- Taps.
        tap_delay_o   : out mag_sq_t;
        tap_et_a_o    : out mag_sq_t;
        tap_et_b_o    : out mag_sq_t;
        tap_ew0_a_o   : out mag_sq_t;
        tap_ew0_b_o   : out mag_sq_t;
        tap_ew1_a_o   : out mag_sq_t;
        tap_ew1_b_o   : out mag_sq_t;
        tap_ew2_a_o   : out mag_sq_t;
        tap_ew2_b_o   : out mag_sq_t;
        tap_ew3_a_o   : out mag_sq_t;
        tap_ew3_b_o   : out mag_sq_t;
        tap_enf_a_o   : out mag_sq_t;
        tap_enf_b_o   : out mag_sq_t;
        tap_ec0_a_o   : out mag_sq_t;
        tap_ec0_b_o   : out mag_sq_t;
        tap_ec1_a_o   : out mag_sq_t;
        tap_ec1_b_o   : out mag_sq_t;
        tap_ec2_a_o   : out mag_sq_t;
        tap_ec2_b_o   : out mag_sq_t;
        tap_ec3_a_o   : out mag_sq_t;
        tap_ec3_b_o   : out mag_sq_t
    );
end adsb_tapped_buffer;

architecture rtl of adsb_tapped_buffer is
    -- Preamble buffer.
    -- Buffer length is as long as the number of samples in the
    -- preamble and is used for preamble detection.
    subtype mag_sq_buffer_index_t is natural range 0 to PREAMBLE_BUFFER_LENGTH-1;
    signal mag_sq_buf_shift_reg : mag_sq_buffer_t(0 to PREAMBLE_BUFFER_LENGTH-1) := (others => (others => '0'));

    -- Tap registers.
    signal tap_delay_r  : mag_sq_t := (others => '0');
    signal tap_et_a_r   : mag_sq_t := (others => '0');
    signal tap_et_b_r   : mag_sq_t := (others => '0');
    signal tap_ew0_a_r  : mag_sq_t := (others => '0');
    signal tap_ew0_b_r  : mag_sq_t := (others => '0');
    signal tap_ew1_a_r  : mag_sq_t := (others => '0');
    signal tap_ew1_b_r  : mag_sq_t := (others => '0');
    signal tap_ew2_a_r  : mag_sq_t := (others => '0');
    signal tap_ew2_b_r  : mag_sq_t := (others => '0');
    signal tap_ew3_a_r  : mag_sq_t := (others => '0');
    signal tap_ew3_b_r  : mag_sq_t := (others => '0');
    signal tap_enf_a_r  : mag_sq_t := (others => '0');
    signal tap_enf_b_r  : mag_sq_t := (others => '0');
    signal tap_ec0_a_r  : mag_sq_t := (others => '0');
    signal tap_ec0_b_r  : mag_sq_t := (others => '0');
    signal tap_ec1_a_r  : mag_sq_t := (others => '0');
    signal tap_ec1_b_r  : mag_sq_t := (others => '0');
    signal tap_ec2_a_r  : mag_sq_t := (others => '0');
    signal tap_ec2_b_r  : mag_sq_t := (others => '0');
    signal tap_ec3_a_r  : mag_sq_t := (others => '0');
    signal tap_ec3_b_r  : mag_sq_t := (others => '0');

begin
    tap_delay_o  <= tap_delay_r;
    tap_et_a_o   <= tap_et_a_r;
    tap_et_b_o   <= tap_et_b_r;
    tap_ew0_a_o  <= tap_ew0_a_r;
    tap_ew0_b_o  <= tap_ew0_b_r;
    tap_ew1_a_o  <= tap_ew1_a_r;
    tap_ew1_b_o  <= tap_ew1_b_r;
    tap_ew2_a_o  <= tap_ew2_a_r;
    tap_ew2_b_o  <= tap_ew2_b_r;
    tap_ew3_a_o  <= tap_ew3_a_r;
    tap_ew3_b_o  <= tap_ew3_b_r;
    tap_enf_a_o  <= tap_enf_a_r;
    tap_enf_b_o  <= tap_enf_b_r;
    tap_ec0_a_o  <= tap_ec0_a_r;
    tap_ec0_b_o  <= tap_ec0_b_r;
    tap_ec1_a_o  <= tap_ec1_a_r;
    tap_ec1_b_o  <= tap_ec1_b_r;
    tap_ec2_a_o  <= tap_ec2_a_r;
    tap_ec2_b_o  <= tap_ec2_b_r;
    tap_ec3_a_o  <= tap_ec3_a_r;
    tap_ec3_b_o  <= tap_ec3_b_r;

    buffer_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- Append most recently arrived sample onto the end of the shift register.
                mag_sq_buf_shift_reg(PREAMBLE_BUFFER_LENGTH-1) <= mag_sq_i;

                -- Then shift the entire buffer.
                for i in 0 to PREAMBLE_BUFFER_LENGTH-2 loop
                    mag_sq_buf_shift_reg(i) <= mag_sq_buf_shift_reg(i+1);
                end loop;
            end if;
        end if;
    end process buffer_process;

    tap_registers_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- Assign each tap register from its buffer position.
                tap_delay_r  <= mag_sq_buf_shift_reg(TAP_PIPELINE_DELAY);
                tap_et_a_r   <= mag_sq_buf_shift_reg(TAP_ET_A_POS);
                tap_et_b_r   <= mag_sq_buf_shift_reg(TAP_ET_B_POS);
                tap_ew0_a_r  <= mag_sq_buf_shift_reg(TAP_EW0_A_POS);
                tap_ew0_b_r  <= mag_sq_buf_shift_reg(TAP_EW0_B_POS);
                tap_ew1_a_r  <= mag_sq_buf_shift_reg(TAP_EW1_A_POS);
                tap_ew1_b_r  <= mag_sq_buf_shift_reg(TAP_EW1_B_POS);
                tap_ew2_a_r  <= mag_sq_buf_shift_reg(TAP_EW2_A_POS);
                tap_ew2_b_r  <= mag_sq_buf_shift_reg(TAP_EW2_B_POS);
                tap_ew3_a_r  <= mag_sq_buf_shift_reg(TAP_EW3_A_POS);
                tap_ew3_b_r  <= mag_sq_buf_shift_reg(TAP_EW3_B_POS);
                tap_enf_a_r  <= mag_sq_buf_shift_reg(TAP_ENF_A_POS);
                tap_enf_b_r  <= mag_sq_buf_shift_reg(TAP_ENF_B_POS);
                tap_ec0_a_r  <= mag_sq_buf_shift_reg(TAP_EC0_A_POS);
                tap_ec0_b_r  <= mag_sq_buf_shift_reg(TAP_EC0_B_POS);
                tap_ec1_a_r  <= mag_sq_buf_shift_reg(TAP_EC1_A_POS);
                tap_ec1_b_r  <= mag_sq_buf_shift_reg(TAP_EC1_B_POS);
                tap_ec2_a_r  <= mag_sq_buf_shift_reg(TAP_EC2_A_POS);
                tap_ec2_b_r  <= mag_sq_buf_shift_reg(TAP_EC2_B_POS);
                tap_ec3_a_r  <= mag_sq_buf_shift_reg(TAP_EC3_A_POS);
                tap_ec3_b_r  <= mag_sq_buf_shift_reg(TAP_EC3_B_POS);
            end if;
        end if;
    end process tap_registers_process;
end rtl;
