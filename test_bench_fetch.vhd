library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_etageFE is
end entity;

architecture test of tb_etageFE is

  -- Signaux d'entrée
  signal clk        : std_logic := '0';
  signal GEL_LI     : std_logic := '0';
  signal PCSrc_ER   : std_logic := '0';
  signal Bpris_EX   : std_logic := '0';
  signal npc        : std_logic_vector(31 downto 0) := (others => '0');
  signal npc_fw_br  : std_logic_vector(31 downto 0) := (others => '0');

  -- Signaux de sortie
  signal pc_plus_4  : std_logic_vector(31 downto 0);
  signal i_FE       : std_logic_vector(31 downto 0);

begin

  -- DUT
  DUT : entity work.etageFE
    port map (
      clk        => clk,
      GEL_LI     => GEL_LI,
      PCSrc_ER   => PCSrc_ER,
      Bpris_EX   => Bpris_EX,
      npc        => npc,
      npc_fw_br  => npc_fw_br,
      pc_plus_4  => pc_plus_4,
      i_FE       => i_FE
    );

  -- Horloge 10 ns (100 MHz)
  clk_process : process
  begin
    while true loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
  end process;

  -- Stimuli
  stim_proc : process
  begin

    -- =========================================================
    -- PHASE 0 : Reset / init (PC bloqué, GEL_LI = 0)
    -- PC doit rester à 0x00000000
    -- =========================================================
    report "=== PHASE 0 : Init (GEL_LI=0, PC bloque a 0) ===";
    GEL_LI    <= '0';
    PCSrc_ER  <= '0';
    Bpris_EX  <= '0';
    npc       <= (others => '0');
    npc_fw_br <= (others => '0');
    wait for 30 ns;

    -- =========================================================
    -- PHASE 1 : Incrément normal du PC (+4 chaque cycle)
    -- PC doit avancer : 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14
    -- =========================================================
    report "=== PHASE 1 : Increment normal PC +4 ===";
    GEL_LI <= '1';
    wait for 60 ns;   -- 6 cycles => PC passe de 0 a 0x18

    -- =========================================================
    -- PHASE 2 : Saut via PCSrc_ER (npc = 0x00000040)
    -- Le PC doit charger 0x40 au prochain front
    -- =========================================================
    report "=== PHASE 2 : Saut PCSrc_ER => 0x00000040 ===";
    npc      <= x"00000040";
    PCSrc_ER <= '1';
    wait for 10 ns;   -- 1 cycle actif
    PCSrc_ER <= '0';
    wait for 40 ns;   -- laisser le PC avancer depuis 0x40

    -- =========================================================
    -- PHASE 3 : Branchement via Bpris_EX (npc_fw_br = 0x00000080)
    -- Le PC doit charger 0x80 au prochain front
    -- =========================================================
    report "=== PHASE 3 : Branchement Bpris_EX => 0x00000080 ===";
    npc_fw_br <= x"00000080";
    Bpris_EX  <= '1';
    wait for 10 ns;   -- 1 cycle actif
    Bpris_EX  <= '0';
    wait for 40 ns;   -- laisser le PC avancer depuis 0x80

    -- =========================================================
    -- PHASE 4 : Gel du pipeline (GEL_LI = 0)
    -- PC doit se figer, pc_plus_4 ne change plus
    -- =========================================================
    report "=== PHASE 4 : Gel pipeline (GEL_LI=0) ===";
    GEL_LI <= '0';
    wait for 40 ns;   -- PC fige pendant 4 cycles

    -- =========================================================
    -- PHASE 5 : Reprise après gel
    -- PC repart depuis la valeur figée
    -- =========================================================
    report "=== PHASE 5 : Reprise apres gel ===";
    GEL_LI <= '1';
    wait for 50 ns;

    -- =========================================================
    -- PHASE 6 : Gel + Saut simultané (GEL_LI prioritaire)
    -- Même si PCSrc_ER=1, le PC ne doit PAS bouger (GEL_LI=0)
    -- =========================================================
    report "=== PHASE 6 : Gel + tentative saut (GEL_LI=0 prioritaire) ===";
    GEL_LI    <= '0';
    npc       <= x"000000FF";
    PCSrc_ER  <= '1';
    wait for 20 ns;
    PCSrc_ER  <= '0';
    GEL_LI    <= '1';
    wait for 30 ns;

    report "=== FIN DE LA SIMULATION ===";
    wait;
  end process;

end architecture;