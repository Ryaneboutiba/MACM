library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_etageDE is
end entity;

architecture test of tb_etageDE is

  -- Entrées
  signal clk       : std_logic := '0';
  signal Init      : std_logic := '0';
  signal RegWr     : std_logic := '0';
  signal RegSrc    : std_logic_vector(1 downto 0) := "00";
  signal immSrc    : std_logic_vector(1 downto 0) := "00";
  signal i_DE      : std_logic_vector(31 downto 0) := (others => '0');
  signal WD_ER     : std_logic_vector(31 downto 0) := (others => '0');
  signal pc_plus_4 : std_logic_vector(31 downto 0) := (others => '0');
  signal Op3_ER    : std_logic_vector(3 downto 0)  := (others => '0');

  -- Sorties
  signal Reg1   : std_logic_vector(3 downto 0);
  signal Reg2   : std_logic_vector(3 downto 0);
  signal Op3_DE : std_logic_vector(3 downto 0);
  signal Op1    : std_logic_vector(31 downto 0);
  signal Op2    : std_logic_vector(31 downto 0);
  signal extlmm : std_logic_vector(31 downto 0);

  -- Procedure d'ecriture dans un registre
  procedure write_reg (
    signal RegWr_s  : out std_logic;
    signal Op3_ER_s : out std_logic_vector(3 downto 0);
    signal WD_ER_s  : out std_logic_vector(31 downto 0);
    constant reg    : in  std_logic_vector(3 downto 0);
    constant val    : in  std_logic_vector(31 downto 0)
  ) is
  begin
    Op3_ER_s <= reg;
    WD_ER_s  <= val;
    RegWr_s  <= '1';
    wait for 10 ns;
    RegWr_s  <= '0';
    wait for 5 ns;
  end procedure;

begin

  DUT : entity work.etageDE
    port map (
      i_DE      => i_DE,
      WD_ER     => WD_ER,
      pc_plus_4 => pc_plus_4,
      Op3_ER    => Op3_ER,
      RegSrc    => RegSrc,
      immSrc    => immSrc,
      RegWr     => RegWr,
      clk       => clk,
      Init      => Init,
      Reg1      => Reg1,
      Reg2      => Reg2,
      Op3_DE    => Op3_DE,
      Op1       => Op1,
      Op2       => Op2,
      extlmm    => extlmm
    );

  -- Horloge 10 ns
  clk_process : process
  begin
    while true loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
  end process;

  stim_proc : process
  begin

    -- =========================================================
    -- PHASE 0 : Initialisation asynchrone du banc de registres
    -- Init=1 => tous les registres a 0
    -- Init=0 => fonctionnement normal
    -- =========================================================
    report "=== PHASE 0 : Init asynchrone ===";
    Init <= '1';
    wait for 15 ns;
    Init <= '0';
    wait for 10 ns;

    -- =========================================================
    -- PHASE 1 : Chargement des registres
    -- On ecrit des valeurs connues dans R0..R5 et R14
    -- pour pouvoir verifier les lectures ensuite
    -- R0=0x00000000 (deja 0 apres init)
    -- R1=0x00000001
    -- R2=0x00000002
    -- R3=0x00000003
    -- R4=0xDEADBEEF
    -- R5=0xFFFFFFFF
    -- R14=0xCAFEBABE
    -- =========================================================
    report "=== PHASE 1 : Chargement des registres ===";

    write_reg(RegWr, Op3_ER, WD_ER, "0001", x"00000001");
    write_reg(RegWr, Op3_ER, WD_ER, "0010", x"00000002");
    write_reg(RegWr, Op3_ER, WD_ER, "0011", x"00000003");
    write_reg(RegWr, Op3_ER, WD_ER, "0100", x"DEADBEEF");
    write_reg(RegWr, Op3_ER, WD_ER, "0101", x"FFFFFFFF");
    write_reg(RegWr, Op3_ER, WD_ER, "1110", x"CAFEBABE");
    wait for 10 ns;

    -- =========================================================
    -- PHASE 2 : CAS 1 - Instruction calcul reg/reg
    -- RegSrc="00" => Op1 vient de i_DE(19..16), Op2 de i_DE(3..0)
    -- Exemple : ADD R3, R1, R2
    --   bits 19..16 = 0001 (Rn=R1)
    --   bits 15..12 = 0011 (Rd=R3)
    --   bits  3.. 0 = 0010 (Rm=R2)
    -- Attendu : Reg1=R1, Reg2=R2, Op3_DE=R3
    --           Op1=0x00000001, Op2=0x00000002
    -- =========================================================
    report "=== PHASE 2 : CAS 1 - Calcul reg/reg RegSrc=00 ===";
    RegSrc <= "00";
    immSrc <= "00";
    -- bits 23..20=cond, 19..16=Rn=R1(0001), 15..12=Rd=R3(0011), 3..0=Rm=R2(0010)
    i_DE   <= "11100000100000010011000000000010";
    wait for 20 ns;

    -- =========================================================
    -- PHASE 3 : CAS 2 - Instruction calcul reg/imm
    -- RegSrc="00", immSrc="00" => imm12 avec extension de signe
    -- Exemple : ADD R3, R1, #255
    --   bits 19..16 = 0001 (Rn=R1)
    --   bits 15..12 = 0011 (Rd=R3)
    --   bits 11.. 0 = 000011111111 (imm12=255=0xFF)
    -- Attendu : extlmm = 0x000000FF
    -- =========================================================
    report "=== PHASE 3 : CAS 2 - Imm12 extension signe positive (immSrc=00) ===";
    RegSrc <= "00";
    immSrc <= "00";
    -- bits 19..16=R1, 15..12=R3, 11..0=0xFF
    i_DE   <= "11100010100000010011000011111111";
    wait for 20 ns;

    -- =========================================================
    -- PHASE 4 : CAS 3 - imm12 negatif (extension de signe)
    -- bits 11..0 = 111111111111 = 0xFFF => signe etendu = 0xFFFFFFFF
    -- Attendu : extlmm = 0xFFFFFFFF
    -- =========================================================
    report "=== PHASE 4 : CAS 3 - Imm12 extension signe negative (immSrc=00) ===";
    RegSrc <= "00";
    immSrc <= "00";
    i_DE   <= "11100010100000010011111111111111";
    wait for 20 ns;

    -- =========================================================
    -- PHASE 5 : CAS 4 - imm12 zero extension (immSrc="01")
    -- bits 11..0 = 111111111111 = 0xFFF
    -- Attendu : extlmm = 0x00000FFF (pas d'extension de signe)
    -- =========================================================
    report "=== PHASE 5 : CAS 4 - Imm12 zero extension (immSrc=01) ===";
    RegSrc <= "00";
    immSrc <= "01";
    i_DE   <= "11100010100000010011111111111111";
    wait for 20 ns;

    -- =========================================================
    -- PHASE 6 : CAS 5 - imm24 pour branchement (immSrc="10")
    -- bits 23..0 = 0x000010 => offset branchement
    -- Attendu : extlmm = 0x00000010 (signe etendu sur 32 bits)
    -- =========================================================
    report "=== PHASE 6 : CAS 5 - Imm24 branchement positif (immSrc=10) ===";
    RegSrc <= "00";
    immSrc <= "10";
    -- bits 23..0 = 0x000010
    i_DE   <= "11101010000000000000000000010000";
    wait for 20 ns;

    -- =========================================================
    -- PHASE 7 : CAS 6 - imm24 negatif pour branchement arriere
    -- bits 23..0 = 0xFFFFFE => offset negatif
    -- Attendu : extlmm = 0xFFFFFFFE
    -- =========================================================
    report "=== PHASE 7 : CAS 6 - Imm24 branchement negatif (immSrc=10) ===";
    RegSrc <= "00";
    immSrc <= "10";
    -- bits 23..0 = 0xFFFFFE
    i_DE   <= "11101010111111111111111111111110";
    wait for 20 ns;

    -- =========================================================
    -- PHASE 8 : CAS 7 - RegSrc(0)=1 => Op1 = R15 (PC)
    -- Branchement : l'operande 1 est le PC (R15)
    -- pc_plus_4 = 0x00000010 => Op1 doit retourner pc_plus_4
    -- =========================================================
    report "=== PHASE 8 : CAS 7 - RegSrc(0)=1 => Op1=R15=PC ===";
    RegSrc   <= "01";
    immSrc   <= "10";
    pc_plus_4 <= x"00000010";
    -- bits 19..16 = 0001 (ignoré car RegSrc(0)=1)
    -- bits 15..12 = 0011 (Rd=R3)
    i_DE     <= "11101010000000010011000000000000";
    wait for 20 ns;
    -- Attendu : Op1 = 0x00000010 (valeur de pc_plus_4 via R15)

    -- =========================================================
    -- PHASE 9 : CAS 8 - RegSrc(1)=1 => Op2 vient de i_DE(15..12)
    -- Instruction memoire LDR/STR : Op2 = Rt = bits 15..12
    --   bits 15..12 = 0100 (Rt=R4)
    --   bits  3.. 0 = 0010 (ignore car RegSrc(1)=1)
    -- Attendu : Reg2=R4, Op2=0xDEADBEEF
    -- =========================================================
    report "=== PHASE 9 : CAS 8 - RegSrc(1)=1 => Op2=i_DE(15..12)=R4 ===";
    RegSrc <= "10";
    immSrc <= "00";
    -- bits 19..16=R1(0001), 15..12=R4(0100), 3..0=R2(0010) (ignore)
    i_DE   <= "11100101100000010100000000000010";
    wait for 20 ns;
    -- Attendu : Reg1=R1, Reg2=R4, Op2=0xDEADBEEF

    -- =========================================================
    -- PHASE 10 : CAS 9 - RegSrc="11" (les deux selecteurs actifs)
    -- Op1 = R15 (PC), Op2 = i_DE(15..12)
    -- =========================================================
    report "=== PHASE 10 : CAS 9 - RegSrc=11 => Op1=R15, Op2=bits15..12 ===";
    RegSrc    <= "11";
    immSrc    <= "10";
    pc_plus_4 <= x"00000020";
    -- bits 15..12=R5(0101), bits 3..0=R2(0010) ignore
    i_DE      <= "11101010000000010101000000000010";
    wait for 20 ns;
    -- Attendu : Op1=0x00000020(PC), Op2=0xFFFFFFFF(R5)

    -- =========================================================
    -- PHASE 11 : CAS 10 - Ecriture pendant lecture (RegWr=1)
    -- On ecrit dans R1 pendant qu'on lit R1
    -- Verifie le comportement write-then-read
    -- =========================================================
    report "=== PHASE 11 : CAS 10 - Ecriture+Lecture simultanées sur R1 ===";
    RegSrc <= "00";
    immSrc <= "00";
    Op3_ER <= "0001";               -- on ecrit dans R1
    WD_ER  <= x"12345678";          -- nouvelle valeur
    RegWr  <= '1';
    -- on lit aussi R1 via i_DE
    i_DE   <= "11100000100000010001000000000010";
    wait for 10 ns;
    RegWr  <= '0';
    wait for 10 ns;

    -- =========================================================
    -- PHASE 12 : CAS 11 - Lecture de R0 (toujours 0 apres init)
    -- =========================================================
    report "=== PHASE 12 : CAS 11 - Lecture R0 = 0x00000000 ===";
    RegSrc <= "00";
    immSrc <= "00";
    -- bits 19..16=R0(0000), 15..12=R0(0000), 3..0=R0(0000)
    i_DE   <= "11100000100000000000000000000000";
    wait for 20 ns;
    -- Attendu : Op1=0, Op2=0

    -- =========================================================
    -- PHASE 13 : CAS 12 - Lecture de R14 (valeur 0xCAFEBABE)
    -- =========================================================
    report "=== PHASE 13 : CAS 12 - Lecture R14=0xCAFEBABE ===";
    RegSrc <= "00";
    immSrc <= "00";
    -- bits 19..16=R14(1110), 15..12=R0(0000), 3..0=R14(1110)
    i_DE   <= "11100000100011100000000000001110";
    wait for 20 ns;
    -- Attendu : Op1=0xCAFEBABE, Op2=0xCAFEBABE

    -- =========================================================
    -- PHASE 14 : CAS 13 - Init asynchrone en cours de simulation
    -- Tous les registres repassent a 0 immediatement
    -- =========================================================
    report "=== PHASE 14 : CAS 13 - Init asynchrone en cours de simulation ===";
    Init <= '1';
    wait for 15 ns;
    Init <= '0';
    -- Relire R1 qui vaut maintenant 0x12345678 mais apres init = 0
    RegSrc <= "00";
    i_DE   <= "11100000100000010001000000000000";
    wait for 20 ns;
    -- Attendu : Op1=0x00000000 (registres remis a 0)

    report "=== FIN DE LA SIMULATION ===";
    wait;
  end process;

end architecture;