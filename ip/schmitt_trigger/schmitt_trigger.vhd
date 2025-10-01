library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.adsb_pkg.all;

-- Schmitt trigger.
entity schmitt_trigger is
    generic (
        SIGNAL_WIDTH : integer := 25
    );
    port (
        clk : in std_logic;
        ce_i : in std_logic;
        i_i : in iq_t;
        q_i : in iq_t;
        mag_sq_i : in unsigned(SIGNAL_WIDTH-1 downto 0);
        high_threshold_i : in unsigned(SIGNAL_WIDTH-1 downto 0);
        low_threshold_i : in unsigned(SIGNAL_WIDTH-1 downto 0);
        detect_i : in std_logic;

        i_o : out iq_t;
        q_o : out iq_t;
        detect_o : out std_logic;
        schmitt_o : out std_logic
    );
end schmitt_trigger;

architecture rtl of schmitt_trigger is
    -- Output registers.
    signal i_r, q_r : iq_t := (others => '0');
    signal schmitt_r : std_logic := '0';
    signal detect_r : std_logic := '0';

begin
    -- Drive outputs with registers.
    i_o <= i_r;
    q_o <= q_r;
    schmitt_o <= schmitt_r;
    detect_o <= detect_r;

    -- Schmitt trigger process.
    trigger_process : process(clk)
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                -- Hysteresis.
                -- Based on threshold levels passed in by the preamble detector.
                if (mag_sq_i > high_threshold_i) then
                    schmitt_r <= '1';
                elsif (mag_sq_i < low_threshold_i) then
                    schmitt_r <= '0';
                end if;

                -- Delayed passthrough/pipeline signals.
                i_r <= i_i;
                q_r <= q_i;
                detect_r <= detect_i;
            end if;
        end if;
    end process trigger_process;
end rtl;
