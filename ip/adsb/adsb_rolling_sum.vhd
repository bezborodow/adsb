library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_rolling_sum is
    generic (
        ROLLING_BUFFER_LENGTH : integer;
        SUM_WIDTH             : integer
    );
    port (
        clk        : in  std_logic;
        ce_i       : in  std_logic;  -- Clock enable.
        incoming_i : in  mag_sq_t;   -- New sample.
        outgoing_i : in  mag_sq_t;   -- Old sample leaving the window.
        sum_o      : out unsigned(SUM_WIDTH-1 downto 0)    -- Current rolling sum.
    );
end adsb_rolling_sum;

architecture rtl of adsb_rolling_sum is
    -- Constrain the buffer to ROLLING_BUFFER_LENGTH
    signal circular_buf : mag_sq_buffer_t(0 to ROLLING_BUFFER_LENGTH-1) := (others => (others => '0'));

    -- Pointer for circular buffer.
    signal head_ptr : integer range 0 to ROLLING_BUFFER_LENGTH-1 := 0;

    -- Sum output register.
    signal sum_r : unsigned(SUM_WIDTH-1 downto 0) := (others => '0');

begin

    -- Drive output registers.
    sum_o <= sum_r;

    -- Circular buffer and rolling sum.
    rolling_buffer_process : process(clk)
        variable incoming_v : unsigned(SUM_WIDTH-1 downto 0);
        variable outgoing_v : unsigned(SUM_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if ce_i = '1' then

                -- Insert incoming sample into the buffer.
                -- (Outgoing sample gets overwritten.)
                circular_buf(head_ptr) <= incoming_i;

                -- Advance circular pointer.
                head_ptr <= (head_ptr + 1) mod ROLLING_BUFFER_LENGTH;

                -- Compute rolling sum.
                incoming_v := resize(incoming_i, SUM_WIDTH);
                outgoing_v := resize(outgoing_i, SUM_WIDTH);
                sum_r <= sum_r + incoming_v - outgoing_v;
            end if;
        end if;
    end process rolling_buffer_process;
end rtl;
