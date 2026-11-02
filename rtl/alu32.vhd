--------------------------------------------------------------------------------
-- alu32 : 32-bit ALU with status flags
--
-- Phase 2. Operation is selected by alu_control and launched by 'start':
--
--   000 NOP   y = 0                     (no flags)
--   001 ADD   y = a + b   (two's complement)   flags C, O, N, Z
--   010 SUB   y = a - b   (two's complement)   flags C, O, N, Z
--   011 MULT  y = a[15:0] * b[15:0] (unsigned, uses multiplier16)   flag Z
--   100 SLT   y = 1 if signed(a) < signed(b) else 0   (no flags)
--   101 AND / 110 OR / 111 XOR   bitwise   (no flags)
--
-- C is the adder carry-out (for SUB: a + not b + 1, so C = 1 means no
-- borrow), O is signed overflow, N is the sign of the result, Z is set when
-- an arithmetic result is zero. 'ready' and all flags are valid for exactly
-- one clock cycle; y holds its value until the next operation.
--
-- Latency: 1 cycle for every operation except MULT (18 cycles).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu32 is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;                     -- synchronous, active high
        start       : in  std_logic;
        a           : in  std_logic_vector(31 downto 0);
        b           : in  std_logic_vector(31 downto 0);
        alu_control : in  std_logic_vector(2 downto 0);
        y           : out std_logic_vector(31 downto 0);
        c, o, n, z  : out std_logic;
        ready       : out std_logic
    );
end entity;

architecture rtl of alu32 is
    constant OP_NOP  : std_logic_vector(2 downto 0) := "000";
    constant OP_ADD  : std_logic_vector(2 downto 0) := "001";
    constant OP_SUB  : std_logic_vector(2 downto 0) := "010";
    constant OP_MULT : std_logic_vector(2 downto 0) := "011";
    constant OP_SLT  : std_logic_vector(2 downto 0) := "100";
    constant OP_AND  : std_logic_vector(2 downto 0) := "101";
    constant OP_OR   : std_logic_vector(2 downto 0) := "110";
    constant OP_XOR  : std_logic_vector(2 downto 0) := "111";

    signal a_reg, b_reg : std_logic_vector(31 downto 0) := (others => '0');
    signal y_reg        : std_logic_vector(31 downto 0) := (others => '0');
    signal mul_start    : std_logic := '0';
    signal mul_y        : std_logic_vector(31 downto 0);
    signal mul_ready    : std_logic;
    signal wait_mul     : std_logic := '0';
begin
    u_mul : entity work.multiplier16
        port map (clk => clk, rst => rst, start => mul_start, a => a_reg, b => b_reg,
                  y => mul_y, ready => mul_ready, busy => open);

    process (clk)
        variable operand_b : unsigned(31 downto 0);
        variable sum       : unsigned(32 downto 0);
        variable result    : std_logic_vector(31 downto 0);
    begin
        if rising_edge(clk) then
            -- flags and ready are single-cycle pulses
            ready     <= '0';
            c         <= '0';
            o         <= '0';
            n         <= '0';
            z         <= '0';
            mul_start <= '0';

            if rst = '1' then
                y_reg    <= (others => '0');
                wait_mul <= '0';

            elsif wait_mul = '1' then
                if mul_ready = '1' then
                    y_reg    <= mul_y;
                    wait_mul <= '0';
                    ready    <= '1';
                    if unsigned(mul_y) = 0 then
                        z <= '1';
                    end if;
                end if;

            elsif start = '1' then
                a_reg <= a;
                b_reg <= b;
                case alu_control is
                    when OP_ADD | OP_SUB =>
                        if alu_control = OP_SUB then
                            operand_b := not unsigned(b);
                            sum := ('0' & unsigned(a)) + ('0' & operand_b) + 1;
                        else
                            operand_b := unsigned(b);
                            sum := ('0' & unsigned(a)) + ('0' & operand_b);
                        end if;
                        result := std_logic_vector(sum(31 downto 0));
                        y_reg  <= result;
                        c      <= sum(32);
                        -- overflow: operands have the same sign, result differs
                        o      <= (a(31) xnor operand_b(31)) and (a(31) xor result(31));
                        n      <= result(31);
                        if unsigned(result) = 0 then
                            z <= '1';
                        end if;
                        ready  <= '1';

                    when OP_MULT =>
                        mul_start <= '1';              -- operands are in a_reg/b_reg next cycle
                        wait_mul  <= '1';

                    when OP_SLT =>
                        if signed(a) < signed(b) then
                            y_reg <= (0 => '1', others => '0');
                        else
                            y_reg <= (others => '0');
                        end if;
                        ready <= '1';

                    when OP_AND => y_reg <= a and b; ready <= '1';
                    when OP_OR  => y_reg <= a or b;  ready <= '1';
                    when OP_XOR => y_reg <= a xor b; ready <= '1';
                    when others =>                     -- OP_NOP
                        y_reg <= (others => '0');
                        ready <= '1';
                end case;
            end if;
        end if;
    end process;

    y <= y_reg;
end architecture;
