--------------------------------------------------------------------------------
-- countdown_timer : minutes:seconds down-counter (bonus assignment)
--
-- A prescaler divides the CLK_HZ clock (50 MHz on the board) into one tick
-- per second. 'load' captures minutes_in:seconds_in; the timer then counts
-- down and raises 'done' when it reaches 00:00, where it stays until the
-- next load. Reset is synchronous and active low, as required.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity countdown_timer is
    generic (
        CLK_HZ : positive := 50_000_000
    );
    port (
        clk        : in  std_logic;
        rst_n      : in  std_logic;                       -- synchronous, active low
        load       : in  std_logic;
        minutes_in : in  unsigned(5 downto 0);            -- 0..59
        seconds_in : in  unsigned(5 downto 0);            -- 0..59
        minutes    : out unsigned(5 downto 0);
        seconds    : out unsigned(5 downto 0);
        done       : out std_logic
    );
end entity;

architecture rtl of countdown_timer is
    signal prescaler : natural range 0 to CLK_HZ - 1 := 0;
    signal min_cnt   : unsigned(5 downto 0) := (others => '0');
    signal sec_cnt   : unsigned(5 downto 0) := (others => '0');
    signal running   : std_logic := '0';
    signal done_i    : std_logic := '0';
begin
    process (clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                prescaler <= 0;
                min_cnt   <= (others => '0');
                sec_cnt   <= (others => '0');
                running   <= '0';
                done_i    <= '0';
            elsif load = '1' then
                prescaler <= 0;
                min_cnt   <= minutes_in;
                sec_cnt   <= seconds_in;
                done_i    <= '0';
                if minutes_in = 0 and seconds_in = 0 then
                    running <= '0';
                    done_i  <= '1';
                else
                    running <= '1';
                end if;
            elsif running = '1' then
                if prescaler = CLK_HZ - 1 then              -- one second has elapsed
                    prescaler <= 0;
                    if sec_cnt = 0 then
                        sec_cnt <= to_unsigned(59, 6);
                        min_cnt <= min_cnt - 1;
                    else
                        sec_cnt <= sec_cnt - 1;
                    end if;
                    if min_cnt = 0 and sec_cnt = 1 then
                        running <= '0';
                        done_i  <= '1';
                    end if;
                else
                    prescaler <= prescaler + 1;
                end if;
            end if;
        end if;
    end process;

    minutes <= min_cnt;
    seconds <= sec_cnt;
    done    <= done_i;
end architecture;
