library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.adsb_pkg.all;

entity adsb_fifo is
    generic (
        FIFO_WIDTH : integer := 177;
        FIFO_DEPTH : integer := 4
    );
    port (
        clk : in std_logic;
        rst : in std_logic;

        -- Write side.
        wr_en   : in std_logic;
        wr_data : in std_logic_vector(FIFO_WIDTH-1 downto 0);
        full    : out std_logic;

        -- Read size.
        rd_en   : in std_logic;
        rd_data : out std_logic_vector(FIFO_WIDTH-1 downto 0);
        rd_vld  : out std_logic;
        empty   : out std_logic
    );
end entity adsb_fifo;

architecture rtl of adsb_fifo is
    type ram_t is array (0 to FIFO_DEPTH-1) of std_logic_vector(FIFO_WIDTH-1 downto 0);
    signal ram : ram_t := (others => (others => '0'));
    signal wr_addr : integer range 0 to FIFO_DEPTH-1 := 0;
    signal rd_addr : integer range 0 to FIFO_DEPTH-1 := 0;
    signal empty_c : std_logic := '1';
    signal full_c : std_logic := '0';
    signal rd_vld_c : std_logic := '0';

    type fifo_state_t is (EMPTYING, FILLING);
    signal sm_fifo : fifo_state_t := EMPTYING;

    signal rd_data_c : std_logic_vector(FIFO_WIDTH-1 downto 0) := (others => '0');

    function circular_incr(
        addr : integer
    ) return integer is
    begin
        return (addr + 1) mod FIFO_DEPTH;
    end function;
begin
    rd_data <= rd_data_c;
    rd_vld <= rd_vld_c;
    empty <= empty_c;
    full <= full_c;

    dual_port_process : process(clk) is
    begin
        if rising_edge(clk) then
        end if;
    end process dual_port_process;
    
    fifo_process : process(clk)
        variable full_v : std_logic := '0';
        variable empty_v : std_logic := '0';
        variable sm_fifo_n : fifo_state_t;
        variable wr_addr_n : integer range 0 to FIFO_DEPTH-1 := 0;
        variable rd_addr_n : integer range 0 to FIFO_DEPTH-1 := 0;
    begin
        if rising_edge(clk) then
            sm_fifo_n := sm_fifo;
            rd_addr_n := rd_addr;
            wr_addr_n := wr_addr;

            -- Determine FIFO state.
            if wr_en = '1' and rd_en = '0' then
                sm_fifo_n := FILLING;
            end if;
            if wr_en = '0' and rd_en = '1' then
                sm_fifo_n := EMPTYING;
            end if;

            -- Write.
            full_v := '1' when (circular_incr(wr_addr_n) = rd_addr_n and sm_fifo = FILLING) else '0';
            if wr_en = '1' and full_v = '0' then
                ram(wr_addr) <= wr_data;
                wr_addr_n := circular_incr(wr_addr);
                full_v := '1' when (circular_incr(wr_addr_n) = rd_addr_n and sm_fifo = FILLING) else '0';
            end if;

            -- Read.
            empty_v := '1' when (wr_addr_n = rd_addr_n and sm_fifo = EMPTYING) else '0';
            if rd_en = '1' and empty_v = '0' then
                rd_data_c <= ram(rd_addr);
                rd_addr_n := circular_incr(rd_addr);
                rd_vld_c <= '1';
            else
                rd_vld_c <= '0';
            end if;

            wr_addr <= wr_addr_n;
            rd_addr <= rd_addr_n;
            empty_c <= empty_v;
            full_c <= full_v;
            sm_fifo <= sm_fifo_n;
        end if;
    end process fifo_process;
end rtl;
