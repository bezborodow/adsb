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
        wr_data_i   : in  std_logic_vector(FIFO_WIDTH-1 downto 0);
        wr_vld_i    : in  std_logic;
        wr_rdy_o    : out std_logic;

        -- Read size.
        rd_data_o   : out std_logic_vector(FIFO_WIDTH-1 downto 0);
        rd_vld_o    : out std_logic;
        rd_rdy_i    : in  std_logic;

        -- Debug signals (do not rely on these for handshaking.)
        full_o      : out std_logic;
        empty_o     : out std_logic
    );
end entity adsb_fifo;

architecture rtl of adsb_fifo is
    -- RAM and addressing.
    type ram_t is array (0 to FIFO_DEPTH-1) of std_logic_vector(FIFO_WIDTH-1 downto 0);
    signal ram : ram_t := (others => (others => '0'));
    signal wr_addr : integer range 0 to FIFO_DEPTH-1 := 0;
    signal rd_addr : integer range 0 to FIFO_DEPTH-1 := 0;

    -- Combinatorial signals.
    signal full_c : std_logic := '0';
    signal empty_c : std_logic := '0';
    signal wr_rdy_c : std_logic := '0';
    signal rd_vld_c : std_logic := '0';

    -- State machine.
    type fifo_state_t is (EMPTYING, FILLING);
    signal sm_fifo : fifo_state_t := EMPTYING;

    -- Increment circular buffer address (using modulus.)
    function circular_incr(
        addr : integer
    ) return integer is
    begin
        return (addr + 1) mod FIFO_DEPTH;
    end function;
begin
    -- Combinatorial signals. Need these since cannot read from output ports.
    full_c <= '1' when wr_addr = rd_addr and sm_fifo = FILLING else '0';
    empty_c <= '1' when wr_addr = rd_addr and sm_fifo = EMPTYING else '0';
    wr_rdy_c <= '1' when full_c = '0' else '0';
    rd_vld_c <= '1' when empty_c = '0' else '0';

    -- Drive output signals.
    full_o <= full_c;
    empty_o <= empty_c;
    wr_rdy_o <= wr_rdy_c;
    rd_vld_o <= rd_vld_c;

    -- Combinatorial data output from current RAM address.
    rd_data_o <= ram(rd_addr);

    fifo_process : process(clk)
        variable sm_fifo_n : fifo_state_t;
        variable wr_en_v : boolean;
        variable rd_en_v : boolean;
    begin
        if rising_edge(clk) then
            sm_fifo_n := sm_fifo;

            wr_en_v := (wr_vld_i = '1') and (wr_rdy_c = '1'); -- TODO cannot read from 'out' object
            rd_en_v := (rd_vld_c = '1') and (rd_rdy_i = '1'); -- TODO cannot read from 'out' object

            -- Determine FIFO state (latching.)
            if wr_en_v and not rd_en_v then
                sm_fifo_n := FILLING;
            end if;
            if not wr_en_v and rd_en_v then
                sm_fifo_n := EMPTYING;
            end if;

            -- Write.
            if wr_en_v then
                ram(wr_addr) <= wr_data_i;
                wr_addr <= circular_incr(wr_addr);
            end if;

            -- Read.
            if rd_en_v then
                rd_addr <= circular_incr(rd_addr);
            end if;

            sm_fifo <= sm_fifo_n;
        end if;
    end process fifo_process;
end rtl;
