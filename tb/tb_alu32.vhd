-- Self-checking testbench for alu32: every example from the assignment,
-- regression cases for the bugs found in the original design, and random
-- operands checked against a reference model.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.tb_util.all;

entity tb_alu32 is
end entity;

architecture sim of tb_alu32 is
    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal start       : std_logic := '0';
    signal a, b, y     : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_control : std_logic_vector(2 downto 0) := "000";
    signal c, o, n, z  : std_logic;
    signal ready       : std_logic;
    signal finished    : boolean := false;

    constant NOP  : std_logic_vector(2 downto 0) := "000";
    constant ADD  : std_logic_vector(2 downto 0) := "001";
    constant SUB  : std_logic_vector(2 downto 0) := "010";
    constant MULT : std_logic_vector(2 downto 0) := "011";
    constant SLT  : std_logic_vector(2 downto 0) := "100";
    constant LAND : std_logic_vector(2 downto 0) := "101";
    constant LOR  : std_logic_vector(2 downto 0) := "110";
    constant LXOR : std_logic_vector(2 downto 0) := "111";
begin
    clk <= not clk after 5 ns when not finished;

    uut : entity work.alu32
        port map (clk => clk, rst => rst, start => start, a => a, b => b,
                  alu_control => alu_control, y => y, c => c, o => o, n => n, z => z,
                  ready => ready);

    stimulus : process
        variable errors, checks : natural := 0;
        variable seed1, seed2   : positive := 7;
        variable r              : real;
        variable ra, rb         : std_logic_vector(31 downto 0);

        procedure run(op : std_logic_vector(2 downto 0); av, bv : std_logic_vector(31 downto 0);
                      ey : std_logic_vector(31 downto 0); ec, eo, en, ez : std_logic; name : string) is
            variable cycles : natural := 0;
        begin
            a <= av;
            b <= bv;
            alu_control <= op;
            start <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            start <= '0';
            while ready /= '1' and cycles < 40 loop
                wait until rising_edge(clk);
                wait for 1 ns;
                cycles := cycles + 1;
            end loop;
            check(ready = '1', name & ": no ready", errors, checks);
            check(y = ey, name & ": Y = " & hex(y) & ", expected " & hex(ey), errors, checks);
            check(c = ec and o = eo and n = en and z = ez,
                  name & ": flags CONZ = " & std_logic'image(c) & std_logic'image(o) &
                  std_logic'image(n) & std_logic'image(z) & ", expected " & std_logic'image(ec) &
                  std_logic'image(eo) & std_logic'image(en) & std_logic'image(ez), errors, checks);
            wait until rising_edge(clk);
            wait for 1 ns;
            check(ready = '0' and c = '0' and o = '0' and n = '0' and z = '0',
                  name & ": ready/flags must last one clock", errors, checks);
        end procedure;

        -- reference model for ADD / SUB
        procedure run_arith(op : std_logic_vector(2 downto 0); av, bv : std_logic_vector(31 downto 0)) is
            variable bb : unsigned(31 downto 0);
            variable s  : unsigned(32 downto 0);
            variable yy : std_logic_vector(31 downto 0);
            variable ov : std_logic;
        begin
            if op = SUB then
                bb := not unsigned(bv);
                s  := ('0' & unsigned(av)) + ('0' & bb) + 1;
            else
                bb := unsigned(bv);
                s  := ('0' & unsigned(av)) + ('0' & bb);
            end if;
            yy := std_logic_vector(s(31 downto 0));
            ov := '0';
            if av(31) = bb(31) and yy(31) /= av(31) then
                ov := '1';
            end if;
            run(op, av, bv, yy, s(32), ov, yy(31), to_sl(unsigned(yy) = 0), "random arith");
        end procedure;

        function slt_ref(av, bv : std_logic_vector(31 downto 0)) return std_logic_vector is
        begin
            if signed(av) < signed(bv) then
                return x"00000001";
            end if;
            return x"00000000";
        end function;

        impure function rand32 return std_logic_vector is
            variable v : std_logic_vector(31 downto 0);
        begin
            uniform(seed1, seed2, r);
            v(31 downto 16) := std_logic_vector(to_unsigned(integer(trunc(r * 65535.0)), 16));
            uniform(seed1, seed2, r);
            v(15 downto 0) := std_logic_vector(to_unsigned(integer(trunc(r * 65535.0)), 16));
            return v;
        end function;
    begin
        wait until rising_edge(clk);
        wait for 1 ns;
        rst <= '0';

        -- Examples from the assignment (expected Y and flags C, O, N, Z)
        run(NOP,  x"638493D8", x"84C6C991", x"00000000", '0', '0', '0', '0', "spec NOP");
        run(ADD,  x"7FFFFFFF", x"7FFFFFFF", x"FFFFFFFE", '0', '1', '1', '0', "spec ADD 1");
        run(ADD,  x"FFFFFFFF", x"FFFFFFFF", x"FFFFFFFE", '1', '0', '1', '0', "spec ADD 2");
        run(SUB,  x"06410D71", x"06417301", x"FFFF9A70", '0', '0', '1', '0', "spec SUB");
        run(MULT, x"0000FFFF", x"0000FFFF", x"FFFE0001", '0', '0', '0', '0', "spec MULT");
        run(SLT,  x"0000BD71", x"0000CDDB", x"00000001", '0', '0', '0', '0', "spec SLT");
        run(LAND, x"A966BD71", x"95C6CDDB", x"81468D51", '0', '0', '0', '0', "spec AND");
        run(LOR,  x"A966BD71", x"95C6CDDB", x"BDE6FDFB", '0', '0', '0', '0', "spec OR");
        run(LXOR, x"A966BD71", x"95C6CDDB", x"3CA070AA", '0', '0', '0', '0', "spec XOR");

        -- Regression cases for bugs in the original submission
        run(SLT,  x"00000005", x"FFFFFFFD", x"00000000", '0', '0', '0', '0', "SLT 5 < -3");
        run(SLT,  x"FFFFFFFD", x"00000005", x"00000001", '0', '0', '0', '0', "SLT -3 < 5");
        run(SLT,  x"80000000", x"7FFFFFFF", x"00000001", '0', '0', '0', '0', "SLT min < max");
        run(SUB,  x"12345678", x"12345678", x"00000000", '1', '0', '0', '1', "SUB zero");
        run(SUB,  x"80000000", x"00000001", x"7FFFFFFF", '1', '1', '0', '0', "SUB overflow");
        run(MULT, x"00000000", x"0000BEEF", x"00000000", '0', '0', '0', '1', "MULT zero");
        run(MULT, x"FFFF0003", x"12340005", x"0000000F", '0', '0', '0', '0', "MULT upper bits ignored");
        run(LAND, x"F0F0F0F0", x"0F0F0F0F", x"00000000", '0', '0', '0', '0', "AND zero sets no Z");

        -- Random operands against the reference model
        for i in 1 to 300 loop
            ra := rand32;
            rb := rand32;
            run_arith(ADD, ra, rb);
            run_arith(SUB, ra, rb);
            run(SLT, ra, rb, slt_ref(ra, rb), '0', '0', '0', '0', "random SLT");
            run(LXOR, ra, rb, ra xor rb, '0', '0', '0', '0', "random XOR");
        end loop;
        for i in 1 to 30 loop
            ra := rand32;
            rb := rand32;
            run(MULT, ra, rb, std_logic_vector(unsigned(ra(15 downto 0)) * unsigned(rb(15 downto 0))),
                '0', '0', '0', to_sl(unsigned(ra(15 downto 0)) * unsigned(rb(15 downto 0)) = 0),
                "random MULT");
        end loop;

        summary("alu32", errors, checks);
        finished <= true;
        wait;
    end process;
end architecture;
