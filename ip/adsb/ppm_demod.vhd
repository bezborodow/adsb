library ieee;
use ieee.std_logic_1164.all;

use ieee.numeric_std.all;
use ieee.math_real.all;

entity ppm_demod is
    generic (
        SAMPLES_PER_SYMBOL : integer := 10
    );
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
end ppm_demod;

architecture Behavioral of ppm_demod is
    constant HALF_SPS : integer := SAMPLES_PER_SYMBOL / 2;
    signal edge_timer : unsigned(15 downto 0) := (others => '0');
begin
    demod_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce then
            end if;
        end if;
    end process demod_process;
end Behavioral;
