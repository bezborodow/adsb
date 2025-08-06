library ieee;                        
use ieee.std_logic_1164.all;         
use ieee.numeric_std.all;            

package correlator_pkg is
  -- your generic-controlled pattern and samples-per-symbol
  constant PREAMBLE_PATTERN   : std_logic_vector := "1010000101000000";
  constant SAMPLES_PER_SYMBOL : integer          := 4;

  -- element type: signed 2-bit (can represent –1, 0, +1)
  subtype sample_t is signed(1 downto 0);

  -- total length
  constant PAT_LEN : integer := PREAMBLE_PATTERN'length;
  constant P_LEN   : integer := PAT_LEN * SAMPLES_PER_SYMBOL;

  -- array type for your mask
  type p_array_t is array(0 to P_LEN-1) of sample_t;

  -- function to expand 1 -> 1,1 and 0 -> –1,–1.
  function expand_pattern(
    pattern : std_logic_vector;
    sps     : integer
  ) return p_array_t;

  -- the final constant mask
  constant p : p_array_t := expand_pattern(PREAMBLE_PATTERN, SAMPLES_PER_SYMBOL);
end package;


package body correlator_pkg is
  function expand_pattern(
    pattern : std_logic_vector;
    sps     : integer
  ) return p_array_t is
    variable result : p_array_t;
    variable idx    : integer := 0;
  begin
    for i in pattern'range loop
      for j in 0 to sps-1 loop
        if pattern(i) = '1' then
          result(idx) := to_signed(1, 2);
        else
          result(idx) := to_signed(-1,2);
        end if;
        idx := idx + 1;
      end loop;
    end loop;
    return result;
  end function;
end package body;
