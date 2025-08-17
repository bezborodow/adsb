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
    signal input_z1 : std_logic := '0';
    signal start_demod : std_logic := '0';
    signal input_rising : std_logic := '0';
    signal input_falling : std_logic := '0';
    signal symbol : std_logic_vector(1 downto 0) := "00";
    signal data_reg : std_logic_vector(111 downto 0) := (others => '0');
begin

    data <= data_reg;

    timing_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce then
                if detect = '1' then
                    edge_timer <= (others => '0');
                    start_demod <= '1';
                else
                    start_demod <= '0';
                    if input = '0' and input_z1 = '1' then
                        input_rising <= '1';
                    else
                        input_rising <= '0';
                    end if;
                    if input = '1' and input_z1 = '0' then
                        input_falling <= '1';
                    else
                        input_falling <= '0';
                    end if;

                    if input_rising or input_falling then
                        edge_timer <= (others => '0');
                    else 
                        edge_timer <= edge_timer + 1;
                    end if;
                end if;
            end if;
            input_z1 <= input;
        end if;
    end process timing_process;

    demod_process : process(clk)
        variable idx : unsigned (6 downto 0) := (others => '0');
        variable pulse_position : std_logic := '0';
    begin
        if rising_edge(clk) then
            if start_demod = '1' then
                pulse_position := '0';
            end if;
            if edge_timer = HALF_SPS-1 then
                pulse_position := not pulse_position;
            end if;
            if edge_timer = HALF_SPS*3-1 then
                pulse_position := not pulse_position;
            end if;
            if edge_timer = HALF_SPS*5-1 then
                -- TODO
            end if;
        end if;

    end process demod_process;

end Behavioral;
