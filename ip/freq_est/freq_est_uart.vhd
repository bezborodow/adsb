library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity freq_est_uart is
    generic (
        ACCUMULATION_LENGTH : integer := 4096;
        UART_CLK_DIV : integer := 521 -- 60_000_000/115200
    );
    port (
        clk : in std_logic;
        d_vld_i : in std_logic; -- In-phase quadrature (IQ) data is valid.
        i_i : in signed(ADC_RX_IQ_WIDTH-1 downto 0); -- In-phase sample.
        q_i : in signed(ADC_RX_IQ_WIDTH-1 downto 0); -- Quadrature sample.
        uart_tx_o : out std_logic -- UART transmission port.
    );
end freq_est_uart;

architecture rtl of freq_est_uart is
    -- FIFO parameters.
    constant FREQ_EST_FIFO_WIDTH : integer := 64;
    constant FREQ_EST_FIFO_DEPTH : integer := 4;

    -- Clock enable.
    signal ce_c : std_logic := '0';

    -- 16 bit IQ to 12 bit registers.
    signal i_rx_12b_r : iq_t := (others => '0');
    signal q_rx_12b_r : iq_t := (others => '0');

    -- Frequency estimator signals.
    signal estimator_start : std_logic := '0';
    signal estimator_vld : std_logic := '0';
    signal estimator_rdy : std_logic := '0';
    signal estimator_re : signed(31 downto 0) := (others => '0');
    signal estimator_im : signed(31 downto 0) := (others => '0');
    signal estimator_fifo_wr_data : std_logic_vector(FREQ_EST_FIFO_WIDTH-1 downto 0); -- Holds packed data for the FIFO.
    signal estimator_enabled : std_logic := '0';

    -- FIFO read side signals.
    signal fifo_rd_data  : std_logic_vector(FREQ_EST_FIFO_WIDTH-1 downto 0);
    signal fifo_rd_vld   : std_logic := '0';
    signal fifo_rd_rdy   : std_logic := '0';

    -- Combinatorial FIFO signals.
    signal fifo_rd_re_c   : signed(31 downto 0);
    signal fifo_rd_im_c   : signed(31 downto 0);

    -- Serialiser signals.
    signal srl_s_vld   : std_logic := '0';
    signal srl_s_last  : std_logic := '0';                  -- Last byte indicator.
    signal srl_s_rdy   : std_logic;
    signal srl_s_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal srl_s_ascii : std_logic := '0';                  -- Convert to ASCII.
    signal srl_s_eom   : std_logic := '0';                  -- End-of-message (newline.)

    -- Encoder signals.
    signal enc_s_vld   : std_logic := '0';
    signal enc_s_rdy   : std_logic;
    signal enc_s_data  : std_logic_vector(7 downto 0) := (others => '0');

    -- UART signals.
    signal uart_tx : std_logic := '1';
begin
    u_freq_est : entity work.freq_est
        generic map (
            ACCUMULATION_LENGTH => ACCUMULATION_LENGTH
        )
        port map (
            clk => clk,
            ce_i => ce_c,
            gate_i => '1', -- Do not gate -- measure constantly.
            start_i => estimator_start,
            stop_i => '0', -- Stop automatically when the accumulator is full.
            i_i => i_rx_12b_r,
            q_i => q_rx_12b_r,
            rdy_i => estimator_rdy,
            vld_o => estimator_vld,
            est_re_o => estimator_re,
            est_im_o => estimator_im,
            enabled_o => estimator_enabled
        );

    u_freq_est_fifo : entity work.adsb_fifo
        generic map (
            FIFO_WIDTH => FREQ_EST_FIFO_WIDTH,
            FIFO_DEPTH => FREQ_EST_FIFO_DEPTH
        )
        port map (
            clk        => clk,
            ce_i       => ce_c,
            rst        => '0',
            wr_data_i  => estimator_fifo_wr_data, -- This data is packed combinatorially for the FIFO.
            wr_vld_i   => estimator_vld,
            wr_rdy_o   => estimator_rdy,
            rd_data_o  => fifo_rd_data,
            rd_vld_o   => fifo_rd_vld,
            rd_rdy_i   => fifo_rd_rdy
        );

    u_freq_est_serialiser : entity work.freq_est_serialiser
        port map (
            clk        => clk,
            ce_i       => ce_c,
            m_vld_i    => fifo_rd_vld,
            m_rdy_o    => fifo_rd_rdy,
            m_est_re_i => fifo_rd_re_c,
            m_est_im_i => fifo_rd_im_c,
            s_vld_o    => srl_s_vld,
            s_last_o   => srl_s_last,
            s_rdy_i    => srl_s_rdy,
            s_data_o   => srl_s_data,
            s_ascii_o  => srl_s_ascii,
            s_eom_o    => srl_s_eom
        );

    u_uart_tx_enc : entity work.uart_tx_enc
        port map (
            clk => clk,
            ce_i => ce_c,
            m_vld_i => srl_s_vld,
            m_rdy_o => srl_s_rdy,
            m_data_i => srl_s_data,
            m_ascii_i => srl_s_ascii,
            m_eom_i => srl_s_eom,
            s_vld_o => enc_s_vld,
            s_rdy_i => enc_s_rdy,
            s_data_o => enc_s_data
        );

    u_uart_tx : entity work.uart_tx
        generic map (
            CLK_DIV => UART_CLK_DIV
        )
        port map (
            clk => clk,
            ce_i => ce_c,
            vld_i => enc_s_vld,
            rdy_o => enc_s_rdy,
            data_i => enc_s_data,
            tx_o => uart_tx
        );

    -- Clock enable.
    ce_c <= d_vld_i; -- Enable clock upon valid IQ data from the ADC.

    -- Extract 12 bit IQ data from 16 bits of the receive (rx) ADC.
    i_rx_12b_r <= resize(i_i, IQ_WIDTH);
    q_rx_12b_r <= resize(q_i, IQ_WIDTH);

    -- Combinatorial packing for FIFO write data.
    estimator_fifo_wr_data <= std_logic_vector(estimator_re) & std_logic_vector(estimator_im);

    -- Combinatorial unpacking from FIFO read data.
    fifo_rd_re_c   <= signed(fifo_rd_data(63 downto 32));
    fifo_rd_im_c   <= signed(fifo_rd_data(31 downto 0));

    -- Drive outputs.
    uart_tx_o <= uart_tx;

    -- Process to restart the estimator after stopping.
    -- Keeps the estimator running in an endless loop.
    stop_start_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_c = '1' then
                -- Check to see if the estimator has stopped (not enabled), but also
                -- waits until the data has been accepted by UART (the valid flag
                -- show be low after a ready/valid handshake.)
                if estimator_enabled = '0' and estimator_vld = '0' then
                    estimator_start <= '1';
                else
                    estimator_start <= '0';
                end if;
            end if;
        end if;
    end process stop_start_process;
end rtl;
