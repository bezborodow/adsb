

    detect_process : process(clk)
        variable all_thresholds_ok : boolean := false;
        variable threshold : unsigned(energy'length-1 downto 0);
        variable local_detect : boolean := false;
        variable energy_history : unsigned_hist_5_t;
        variable max_magnitude : unsigned(MAGNITUDE_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if ce_i = '1' then
                threshold := resize((energy * to_unsigned(3, energy'length+2)) srl 4, energy'length);
                all_thresholds_ok := true;
                for i in PREAMBLE_POSITION'range loop
                    if resize(sym_energy(i), energy'length) <= threshold then
                        all_thresholds_ok := false;
                    end if;
                end loop;

                if all_thresholds_ok then
                    local_detect := true;
                else
                    local_detect := false;
                end if;

                energy_history(4) := energy_history(3);
                energy_history(3) := energy_history(2);
                energy_history(2) := energy_history(1);
                energy_history(1) := energy_history(0);
                if local_detect then
                    energy_history(0) := energy;
                else
                    energy_history(0) := (others => '0');
                end if;

                if energy_history(2) > 0 then
                    if (energy_history(2) > energy_history(0)) and
                       (energy_history(2) > energy_history(1)) and
                       (energy_history(2) > energy_history(3)) and
                       (energy_history(2) > energy_history(4)) then
                        detect_o <= '1';
                        max_magnitude := max_over_preamble(shift_reg);
                        high_threshold_c <= max_magnitude srl 1;
                        low_threshold_c <= max_magnitude srl 3;
                    else
                        detect_o <= '0';
                    end if;
                else
                    detect_o <= '0';
                end if;
            end if;
        end if;
    end process detect_process;
