-- Small helpers shared by the self-checking testbenches.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tb_util is
    procedure check(cond : boolean; msg : string;
                    variable errors : inout natural; variable checks : inout natural);
    procedure summary(name : string; errors, checks : natural);
    function hex(v : std_logic_vector) return string;
    function to_sl(b : boolean) return std_logic;
end package;

package body tb_util is
    procedure check(cond : boolean; msg : string;
                    variable errors : inout natural; variable checks : inout natural) is
    begin
        checks := checks + 1;
        if not cond then
            errors := errors + 1;
            report "CHECK FAILED: " & msg severity error;
        end if;
    end procedure;

    procedure summary(name : string; errors, checks : natural) is
    begin
        if errors = 0 then
            report "PASS " & name & " (" & integer'image(checks) & " checks)" severity note;
        else
            report "FAIL " & name & " (" & integer'image(errors) & " of " &
                   integer'image(checks) & " checks failed)" severity error;
        end if;
    end procedure;

    function hex(v : std_logic_vector) return string is
    begin
        return to_hstring(v);
    end function;

    function to_sl(b : boolean) return std_logic is
    begin
        if b then
            return '1';
        end if;
        return '0';
    end function;
end package body;
