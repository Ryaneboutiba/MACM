-------------------------------------------------

-- Etage FE

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity etageFE is
  port(
    npc, npc_fw_br : in std_logic_vector(31 downto 0);
    PCSrc_ER, Bpris_EX, GEL_LI, clk : in std_logic;
    pc_plus_4, i_FE : out std_logic_vector(31 downto 0)
);
end entity;


architecture etageFE_arch of etageFE is
  signal pc_inter, pc_reg_in, pc_reg_out, sig_pc_plus_4, sig_4: std_logic_vector(31 downto 0);
begin

  sig_4 <= (2=>'1', others => '0');
  
  
  
  pc_inter<=npc when PCSrc_ER='1'else
            sig_pc_plus_4;


  pc_reg_in<=pc_inter when Bpris_EX='0' else
              npc_fw_br;
  
  inst_regbank : entity work.Reg32 port map(
    source=>pc_reg_in,
    output=>pc_reg_out,
    wr=>GEL_LI,
    raz=>'1',
    clk=>clk
  );

  inst_mem_inst : entity work.inst_mem port map(pc_reg_out,i_FE);
  inst_comb_add : entity work.addComplex port map (
    A   => pc_reg_out,
    B   => sig_4,
    Cin => '0',             
    S   => sig_pc_plus_4
  );
  pc_plus_4<=sig_pc_plus_4;

end architecture;

-- -------------------------------------------------

-- Etage DE

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity etageDE is
  port(
    i_DE,WD_ER,pc_plus_4 : in std_logic_vector(31 downto 0);
    Op3_ER : in std_logic_vector(3 downto 0);
    RegSrc, immSrc : in std_logic_vector(1 downto 0);
    RegWr, clk,Init: in std_logic;
    Reg1,Reg2,Op3_DE : out std_logic_vector(3 downto 0);
    Op1,Op2,extlmm : out std_logic_vector(31 downto 0)
  );
end entity;


architecture behaviour of etageDE is
  signal sigOP1,sigOP2 : std_logic_vector(3 downto 0);
  signal immIn_sig : std_logic_vector(23 downto 0);
  begin
  sigOP1<= i_DE(19 downto 16) when RegSrc(0)='0' else
    std_logic_vector(to_unsigned(15, 4));

  sigOP2<= i_DE(3 downto 0) when RegSrc(1)='0' else
           i_DE(15 downto 12);

  Op3_DE<=i_DE(15 downto 12);

  inst_reg_bank : entity work.RegisterBank port map (
    s_reg_0=>sigOp1,
    data_o_0=>Op1,
    s_reg_1=>sigOP2,
    data_o_1=>Op2,
    data_i=>WD_ER,
    wr_reg=>RegWr,
    pc_in=>pc_plus_4,
    dest_reg=>Op3_ER,
    clk=> clk,
    init=>Init
  );
  
  Reg1<=sigOp1;
  Reg2<=sigOP2;

  immIn_sig <= i_DE(23 downto 0);

  -- Extension de l'immédiat via le composant dédié
  inst_ext : entity work.extension port map (
    immIn  => immIn_sig,
    immSrc => immSrc,
    ExtOut => extlmm
  );


  end architecture;

-- -------------------------------------------------

-- -- Etage EX

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity etageEX is
  port(
    Op1_EX,Op2_EX,Extlmm_EX,Res_fwd_ME,Res_fwd_ER : in std_logic_vector(31 downto 0);
    Op3_EX: std_logic_vector(3 downto 0);
    EA_EX,EB_EX,ALU_Ctrl_EX: in std_logic_vector(1 downto 0);
    ALU_Src_EX : in std_logic;
    CC: out std_logic_vector(3 downto 0);
    Res_EX,WD_EX,npc_fw_br : out std_logic_vector(31 downto 0);
    OP3_EX_out : out std_logic_vector(3 downto 0)
  );
end entity;


architecture behaviour of etageEx is
  signal ALUOp1,Oper2,ALUOp2,Res : std_logic_vector(31 downto 0);
begin
  OP3_EX_out<=Op3_EX;

  WD_EX<=Op2_EX;

  ALUOp1<=Op1_EX when EA_EX(1)='0' and EA_EX(0)='0' else
          Res_fwd_ER when EA_EX(1)='0' and EA_EX(0)='1' else
          Res_fwd_ME;

  Oper2<=Op2_EX when EB_EX(1)='0' and EB_EX(0)='0' else
         Res_fwd_ER when EB_EX(1)='0' and EB_EX(0)='1' else
         Res_fwd_ME;

  ALUOp2<=Oper2 when ALU_Src_EX='0' else
          Extlmm_EX;

  inst_alu : entity work.ALU  port map(
    A=>ALUOp1,
    B=>ALUOp2,
    sel=>ALU_Ctrl_EX,
    Res=>Res
  );

  Res_EX<= Res;
  npc_fw_br<=Res;

  end architecture;

-- -------------------------------------------------

-- -- Etage ME

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity etageME is
  port(
    Res_ME,WD_ME : in std_logic_vector(31 downto 0);
    OP3_ME : in std_logic_vector(3 downto 0);
    clk,MemWR_Mem : in std_logic;
    Res_Mem_ME,Res_ALU_ME,Res_fwd_ME : out std_logic_vector(31 downto 0);
    Op3_ME_out : out std_logic_vector(3 downto 0)
  );
end entity;


architecture behaviour of etageME is 
begin
  Op3_ME_out<=OP3_ME;
  Res_ALU_ME<=Res_ME;
  Res_fwd_ME<=Res_ME;

  inst_memD : entity work.data_mem port map(
    addr=>Res_ME,
    WD=>WD_ME,
    WR=>MemWR_Mem,
    clk=>clk,
    data =>Res_Mem_ME
  );

end architecture;

-- -------------------------------------------------

-- -- Etage ER

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity etageER is
  port(
    Res_Mem_RE,Res_ALU_ME : in  std_logic_vector(31 downto 0);
    OP3_RE : in std_logic_vector( 3 downto 0);
    MemToReg_RE: in std_logic;
    Res_RE : out std_logic_vector(31 downto 0);
    OP3_RE_out : out std_logic_vector(3 downto 0)
  );
end entity;


architecture behaviour of etageER is 
begin
  OP3_RE_out<=OP3_RE;
  Res_RE<= Res_Mem_RE when MemToReg_RE='1' else
           Res_ALU_ME;

  end architecture;

