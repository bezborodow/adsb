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
        wr_en   : in  std_logic;
        wr_data : in  std_logic_vector(FIFO_WIDTH-1 downto 0);
        full    : out std_logic;

        -- Read size.
        rd_en   : in  std_logic;
        rd_data : out std_logic_vector(FIFO_WIDTH-1 downto 0);
        empty   : out std_logic
    );
end entity adsb_fifo;

architecture rtl of adsb_fifo is
    type ram_t is array (0 to FIFO_DEPTH-1) of std_logic_vector(FIFO_WIDTH-1 downto 0);
    signal ram     : ram_t;
    signal wr_ptr  : integer range 0 to FIFO_DEPTH-1 := 0;
    signal rd_ptr  : integer range 0 to FIFO_DEPTH-1 := 0;
    signal count   : integer range 0 to FIFO_DEPTH   := 0;
begin
    full  <= '1' when count = FIFO_DEPTH else '0';
    empty <= '1' when count = 0 else '0';

    fifo_process : process(clk)
        variable tmp_count : integer range 0 to FIFO_DEPTH := 0;
    begin
        if rising_edge(clk) then
            tmp_count := count;
            if rst = '1' then
                wr_ptr <= 0;
                rd_ptr <= 0;
                rd_data <= (others => '0');
                tmp_count := 0;
            else
                -- Write.
                if (wr_en = '1') and (tmp_count < FIFO_DEPTH) then
                    ram(wr_ptr) <= wr_data;
                    wr_ptr <= (wr_ptr + 1) mod FIFO_DEPTH;
                    tmp_count := tmp_count + 1;
                end if;

                -- Read.
                if (rd_en = '1') and (tmp_count > 0) then
                    rd_data <= ram(rd_ptr);
                    rd_ptr <= (rd_ptr + 1) mod FIFO_DEPTH;
                    tmp_count := tmp_count - 1;
                end if;
            end if;

            count <= tmp_count;
        end if;
    end process fifo_process;
end rtl;
