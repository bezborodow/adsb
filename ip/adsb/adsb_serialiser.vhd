library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity adsb_serialiser is
    port (
        clk : in std_logic;

        -- Master (ADSB.)
        m_vld_i : in std_logic;
        m_rdy_o : out std_logic;
        m_w56_i : in std_logic;
        m_data_i : in std_logic_vector(111 downto 0);
        m_est_re_i : in signed(31 downto 0);
        m_est_im_i : in signed(31 downto 0);

        -- Slave (serialised data.)
        s_vld_o : out std_logic;
        s_last_o : out std_logic;
        s_rdy_i : in std_logic;
        s_data_o : out std_logic_vector(7 downto 0);
        s_ascii_o : out std_logic;
        s_eom_o : out std_logic
    );
end adsb_serialiser;

architecture rtl of adsb_serialiser is
begin
end rtl;
