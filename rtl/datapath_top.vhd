--------------------------------------------------------------------------------
-- datapath_top : the four phases connected into one pipeline
--
--   alu32 --(y, ready)--> seq_detector --(data_out, out_valid)--> packet_checker
--
-- Every ALU result is scanned for the code 01111101; only words that contain
-- it are forwarded to the packet checker, which writes valid packets to RAM.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity datapath_top is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;
        a, b        : in  std_logic_vector(31 downto 0);
        alu_control : in  std_logic_vector(2 downto 0);
        -- ALU status
        alu_y       : out std_logic_vector(31 downto 0);
        alu_ready   : out std_logic;
        c, o, n, z  : out std_logic;
        -- sequence detector
        detected    : out std_logic;
        -- RAM interface
        ram_en      : out std_logic;
        ram_address : out std_logic_vector(7 downto 0);
        ram_data    : out std_logic_vector(15 downto 0);
        error       : out std_logic
    );
end entity;

architecture rtl of datapath_top is
    signal y         : std_logic_vector(31 downto 0);
    signal ready     : std_logic;
    signal word      : std_logic_vector(31 downto 0);
    signal word_vld  : std_logic;
begin
    u_alu : entity work.alu32
        port map (clk => clk, rst => rst, start => start, a => a, b => b,
                  alu_control => alu_control, y => y, c => c, o => o, n => n, z => z,
                  ready => ready);

    u_det : entity work.seq_detector
        port map (clk => clk, rst => rst, start => ready, y_in => y, detected => detected,
                  data_out => word, out_valid => word_vld, busy => open);

    u_pkt : entity work.packet_checker
        generic map (PARITY_CHECK => true)
        port map (clk => clk, rst => rst, valid => word_vld, packet => word, ram_en => ram_en,
                  ram_address => ram_address, ram_data => ram_data, error => error);

    alu_y     <= y;
    alu_ready <= ready;
end architecture;
