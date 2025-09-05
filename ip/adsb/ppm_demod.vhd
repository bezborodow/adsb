library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity ppm_demod is
    generic (
        SAMPLES_PER_SYMBOL : integer := ADSB_DEFAULT_SAMPLES_PER_SYMBOL
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic;
        envelope_i : in std_logic;
        detect_i : in std_logic;
        vld_o : out std_logic;
        w56_o : out std_logic;
        rdy_i : in std_logic;
        malformed_o : out std_logic;
        data_o : out std_logic_vector(111 downto 0)
    );
end ppm_demod;
architecture Behavioral of ppm_demod is
    constant HALF_SPS : integer := SAMPLES_PER_SYMBOL / 2;
    signal edge_timer : unsigned(15 downto 0) := (others => '0');
    signal envelope_z1 : std_logic := '0';
    signal start_demod : std_logic := '0';
    --signal symbol : std_logic_vector(1 downto 0) := "00";
    signal data_r : std_logic_vector(111 downto 0) := (others => '0');
    signal malformed_r : std_logic := '0';
    signal valid_r : std_logic := '0';
    signal w56_r : std_logic := '0';
    signal ce_r : std_logic := '0';
begin

    data_o <= data_r;
    malformed_o <= malformed_r;
    vld_o <= valid_r;
    w56_o <= w56_r;
    ce_r <= ce_i;

    timing_process : process(clk)
        variable input_rising : std_logic := '0';
        variable input_falling : std_logic := '0';
    begin
        if rising_edge(clk) then
            if ce_r = '1' then
                if detect_i = '1' then
                    edge_timer <= (others => '0');
                    start_demod <= '1';
                else
                    start_demod <= '0';
                    if envelope_i = '0' and envelope_z1 = '1' then
                        input_rising := '1';
                    else
                        input_rising := '0';
                    end if;
                    if envelope_i = '1' and envelope_z1 = '0' then
                        input_falling := '1';
                    else
                        input_falling := '0';
                    end if;

                    if input_rising = '1' or input_falling = '1' then
                        edge_timer <= (others => '0');
                    else 
                        edge_timer <= edge_timer + 1;
                    end if;
                end if;
            end if;
            envelope_z1 <= envelope_i;
        end if;
    end process timing_process;

    demod_process : process(clk)
        variable index : unsigned(6 downto 0) := (others => '0');
        variable pulse_position : unsigned(0 downto 0) := "0";
        variable symbol : std_logic_vector(1 downto 0) := "00";
        variable do_sample : boolean := false;
        variable sample : std_logic := '0';
        variable invalid_symbol : boolean := false;
    begin
        if rising_edge(clk) then
            if ce_r = '1' and valid_r = '0' then
                if start_demod = '1' then
                    pulse_position := "1";
                    index := (others => '0');
                    malformed_r <= '0';
                    valid_r <= '0';
                    data_r <= (others => '0');
                    w56_r <= '0';
                elsif malformed_r = '0' then
                    do_sample := false;
                    if edge_timer = HALF_SPS-1 then
                        pulse_position := not pulse_position;
                        do_sample := true;
                    end if;
                    if edge_timer = HALF_SPS*3-1 then
                        pulse_position := not pulse_position;
                        do_sample := true;
                    end if;
                    if edge_timer = HALF_SPS*5-1 then
                        if index = 56 and envelope_z1 = '0' then
                            valid_r <= '1';
                            w56_r <= '1';
                        else
                            malformed_r <= '1';
                        end if;
                    end if;

                    if do_sample then
                        symbol(to_integer(pulse_position)) := envelope_z1;
                        if pulse_position = "1" and to_integer(index) < 112 then
                            invalid_symbol := false;
                            if symbol = "01" then
                                sample := '1';
                            elsif symbol = "10" then
                                sample := '0';
                            else
                                invalid_symbol := true;
                            end if;
                            if not invalid_symbol then
                                data_r(to_integer(index)) <= sample;
                                if index = 111 then
                                    valid_r <= '1';
                                end if;
                                index := index + 1;
                            elsif invalid_symbol and index = 56 then
                                valid_r <= '1';
                                w56_r <= '1';
                            else
                                malformed_r <= '1';
                            end if;
                        end if;
                    end if;
                end if;
            end if;

            if ce_r = '1' and valid_r = '1' and rdy_i = '1' then
                valid_r <= '0';
                data_r <= (others => '0');
                w56_r <= '0';
            end if;
        end if;

    end process demod_process;

end Behavioral;
