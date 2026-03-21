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
    -- PHASE 0 : Reset / init
    -- =========================================================
    report "=== PHASE 0 : Init (GEL_LI=0) ===";
    GEL_LI    <= '0';
    PCSrc_ER  <= '0';
    Bpris_EX  <= '0';
    npc       <= (others => '0');
    npc_fw_br <= (others => '0');
    wait for 20 ns;

    -- =========================================================
    -- PHASE 1 : Incrément normal du PC (+4)
    -- i_FE doit afficher 0x00 -> 0x01 -> ... -> 0x0A
    -- =========================================================
    report "=== PHASE 1 : Increment normal PC +4 ===";
    GEL_LI <= '1';
    wait for 110 ns;   -- 11 cycles pour voir i_FE jusqu'a 0x0A

    -- =========================================================
    -- PHASE 2 : Gel simple (GEL_LI 1 -> 0 -> 1)
    -- PC doit se figer puis reprendre normalement
    -- =========================================================
    report "=== PHASE 2 : Gel simple (GEL_LI=1->0->1) ===";
    GEL_LI <= '0';
    wait for 40 ns;    -- PC fige pendant 4 cycles
    GEL_LI <= '1';
    wait for 30 ns;    -- reprise normale

    -- =========================================================
    -- PHASE 3 : Gel + Bpris_EX simultané
    -- GEL_LI passe a 0 EN MEME TEMPS que Bpris_EX passe a 1
    -- Le PC ne doit PAS sauter (gel prioritaire sur branchement)
    -- =========================================================
    report "=== PHASE 3 : Gel + Bpris_EX simultane (gel prioritaire) ===";
    npc_fw_br <= x"00000080";
    GEL_LI    <= '0';   -- gel
    Bpris_EX  <= '1';   -- branchement en meme temps
    wait for 30 ns;     -- PC doit rester fige malgre Bpris_EX=1
    Bpris_EX  <= '0';
    GEL_LI    <= '1';   -- reprise
    wait for 30 ns;     -- PC repart depuis valeur figee (pas 0x80)

    -- =========================================================
    -- PHASE 4 : Gel + PCSrc_ER simultané
    -- GEL_LI passe a 0 EN MEME TEMPS que PCSrc_ER passe a 1
    -- Le PC ne doit PAS sauter (gel prioritaire sur saut)
    -- =========================================================
    report "=== PHASE 4 : Gel + PCSrc_ER simultane (gel prioritaire) ===";
    npc      <= x"00000040";
    GEL_LI   <= '0';   -- gel
    PCSrc_ER <= '1';   -- saut en meme temps
    wait for 30 ns;    -- PC doit rester fige malgre PCSrc_ER=1
    PCSrc_ER <= '0';
    GEL_LI   <= '1';   -- reprise
    wait for 30 ns;    -- PC repart depuis valeur figee (pas 0x40)

    -- =========================================================
    -- PHASE 5 : Saut normal PCSrc_ER (sans gel)
    -- Confirme que PCSrc_ER fonctionne bien quand GEL_LI=1
    -- =========================================================
    report "=== PHASE 5 : Saut normal PCSrc_ER => 0x40 (GEL_LI=1) ===";
    npc      <= x"00000040";
    PCSrc_ER <= '1';
    wait for 10 ns;
    PCSrc_ER <= '0';
    wait for 40 ns;

    -- =========================================================
    -- PHASE 6 : Branchement normal Bpris_EX (sans gel)
    -- Confirme que Bpris_EX fonctionne bien quand GEL_LI=1
    -- =========================================================
    report "=== PHASE 6 : Branchement normal Bpris_EX => 0x80 (GEL_LI=1) ===";
    npc_fw_br <= x"00000080";
    Bpris_EX  <= '1';
    wait for 10 ns;
    Bpris_EX  <= '0';
    wait for 40 ns;

    report "=== FIN DE LA SIMULATION ===";
    wait;
  end process;

end architecture;