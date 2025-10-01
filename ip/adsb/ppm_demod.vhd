library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity ppm_demod is
    generic (
        SAMPLES_PER_SYMBOL : positive -- TODO rename: this is strictly samples per pulse? SPS would be twice this.
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic;
        envelope_i : in std_logic; -- TODO rename: this is not the envelope; it is the cleaned up signal from the trigger!
        detect_i : in std_logic;
        vld_o : out std_logic;
        w56_o : out std_logic;
        rdy_i : in std_logic;
        malformed_o : out std_logic;
        data_o : out std_logic_vector(111 downto 0)
    );
end ppm_demod;
architecture rtl of ppm_demod is
    constant HALF_SPS : integer := SAMPLES_PER_SYMBOL / 2;

    -- Track when the demodulator is active.
    signal demodulating : std_logic := '0';

    -- Delay registers.
    signal envelope_z1 : std_logic := '0';
    signal detect_z1 : std_logic := '0';

    -- Timing process.
    signal sample_strobe : std_logic := '0';

    -- Symbol process.
    signal symbol_strobe : std_logic := '0';


    -- Signals for pulse position process.
    signal pulse_position : std_logic_vector(1 downto 0) := "00";
    signal pp_strobe : std_logic := '0';

    -- Output registers.
    signal data_r : std_logic_vector(111 downto 0) := (others => '0');
    signal malformed_r : std_logic := '0';
    signal valid_r : std_logic := '0';
    signal w56_r : std_logic := '0';
begin
    -- Drive output ports with registers.
    data_o <= data_r;
    malformed_o <= malformed_r;
    vld_o <= valid_r;
    w56_o <= w56_r;

    -- The timing process keeps track of edges and creates
    -- a sample strobe that is used to trigger a sample read
    -- midway through the symbol.
    timing_process : process(clk)
        constant EDGE_TIMER_MAX : positive := SAMPLES_PER_SYMBOL-1;
        variable input_rising : std_logic := '0';
        variable input_falling : std_logic := '0';
        variable edge_timer : natural range 0 to EDGE_TIMER_MAX := 0;
        
        -- To detect the first symbol, allow slack of two samples to be low.
        variable startup_mode : boolean := false;
        variable prev_symbol_low : boolean := false;
        variable first_strobe_sent : boolean := false;
        variable send_strobe : boolean := false;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                if detect_i = '1' then
                    -- Reset timer on preamble detection.
                    -- Do nothing else.
                    -- Don't check envelope_z1 because it might not be setup correctly by the Schmitt trigger thresholds yet.
                    edge_timer := 0;
                    startup_mode := true;
                    prev_symbol_low := false;
                    first_strobe_sent := false;
                    send_strobe := false;
                end if;

                if demodulating = '1' then
                    -- Detect rising or falling edges.
                    if envelope_i = '1' and envelope_z1 = '0' then
                        input_rising := '1';
                    else
                        input_rising := '0';
                    end if;
                    if envelope_i = '0' and envelope_z1 = '1' then
                        input_falling := '1';
                    else
                        input_falling := '0';
                    end if;

                    -- Reset the timer on an edge or when overflowing.
                    if input_rising = '1' or input_falling = '1' or edge_timer = EDGE_TIMER_MAX then
                        edge_timer := 0;
                    else
                        edge_timer := edge_timer + 1;
                    end if;

                    -- Sample when halfway through the timer.
                    if edge_timer = HALF_SPS-1 then

                        -- This next section basically just sets the sample_strobe, but
                        -- has extra logic to allow the first two samples to be low during
                        -- startup. This allows the preamble to be slightly out of time.
                        send_strobe := false;
                        if not startup_mode then
                            send_strobe := true;
                        end if;
                        if not prev_symbol_low then
                            send_strobe := true;
                        end if;
                        if not first_strobe_sent then
                            send_strobe := true;
                        end if;
                        if envelope_i = '1' then
                            send_strobe := true;
                        end if;

                        if send_strobe then
                            sample_strobe <= '1';
                            first_strobe_sent := true;
                            if envelope_i = '0' then
                                prev_symbol_low := true;
                            else
                                startup_mode := false;
                            end if;
                        end if;
                    else
                        sample_strobe <= '0';
                    end if;
                end if;

                -- Delay for the next process.
                detect_z1 <= detect_i;
                envelope_z1 <= envelope_i;
            end if;
        end if;
    end process timing_process;

    symbol_process : process(clk)
        variable pp_index : natural range 0 to 1 := 0;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                if detect_i = '1' then
                    -- Reset.
                    pp_index := 0;
                end if;

                if demodulating = '1' then

                    -- Fill up symbols from samples whenever a sample strobe is fired
                    -- from the timing process.
                    pp_strobe <= '0';
                    if sample_strobe = '1' then
                        pulse_position(pp_index) <= envelope_z1;
                        if pp_index = 0 then
                            pp_index := 1;
                        else
                            pp_index := 0;
                            pp_strobe <= '1'; -- Symbol found.
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process symbol_process;

    demod_process : process(clk)
        variable bit_index : natural range 0 to 111 := 0;
    begin
        if rising_edge(clk) then
            if ce_i = '1' then

                -- Reset when new preamble is detected.
                if detect_i = '1' then
                    malformed_r <= '0';
                    valid_r <= '0';
                    data_r <= (others => '0');
                    w56_r <= '0';
                    bit_index := 0;

                    -- Start demodulating.
                    demodulating <= '1';
                end if;

                if demodulating = '1' then
                    if pp_strobe = '1' then
                        if pulse_position = "01" or pulse_position = "10" then
                            -- Shift new bit onto the data register.
                            data_r <= data_r(110 downto 0) & pulse_position(0);

                            -- Check end of 112 bit message.
                            if bit_index = 111 then
                                valid_r <= '1';
                                demodulating <= '0';
                            else
                                bit_index := bit_index + 1;
                            end if;
                        elsif pulse_position = "00" and bit_index = 56 then
                            -- End of 56 bit message.
                            w56_r <= '1';
                            valid_r <= '1';
                            demodulating <= '0';
                        else
                            -- Invalid symbol. Malformed.
                            malformed_r <= '1';
                            demodulating <= '0';
                        end if;
                    end if;
                end if;

                -- Clear valid flag after handshake once data is transferred.
                if valid_r = '1' and rdy_i = '1' then
                    valid_r <= '0';
                end if;
            end if;
        end if;
    end process demod_process;

end rtl;
