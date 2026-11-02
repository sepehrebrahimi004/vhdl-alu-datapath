--------------------------------------------------------------------------------
-- packet_checker : validates a 32-bit packet and writes it to a RAM port
--
-- Phase 4. Packet layout (nibbles, LSB first):
--
--   bits  3..0   header   must be "1010" (0xA)
--   bits 11..4   address  (Address2 & Address1)
--   bits 27..12  data     (Data4 & Data3 & Data2 & Data1)
--   bits 31..28  check    bit 31 = even parity of Data4 (bits 27..24),
--                         bit 30 -> Data3, bit 29 -> Data2, bit 28 -> Data1
--
-- For a packet with a valid header, ram_en pulses for one clock with the
-- address and data; if parity checking is enabled and a check bit is wrong,
-- error pulses for one clock instead. Packets with another header are
-- ignored. Every 'valid' strobe is processed (no one-shot behaviour).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity packet_checker is
    generic (
        PARITY_CHECK : boolean := true                    -- the bonus part
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;                      -- synchronous, active high
        valid       : in  std_logic;
        packet      : in  std_logic_vector(31 downto 0);
        ram_en      : out std_logic;
        ram_address : out std_logic_vector(7 downto 0);
        ram_data    : out std_logic_vector(15 downto 0);
        error       : out std_logic
    );
end entity;

architecture rtl of packet_checker is
    constant HEADER : std_logic_vector(3 downto 0) := "1010";

    function parity(v : std_logic_vector(3 downto 0)) return std_logic is
    begin
        return v(3) xor v(2) xor v(1) xor v(0);
    end function;

    function check_ok(p : std_logic_vector(31 downto 0)) return boolean is
    begin
        return parity(p(27 downto 24)) = p(31) and parity(p(23 downto 20)) = p(30) and
               parity(p(19 downto 16)) = p(29) and parity(p(15 downto 12)) = p(28);
    end function;
begin
    process (clk)
    begin
        if rising_edge(clk) then
            ram_en <= '0';
            error  <= '0';
            if rst = '1' then
                ram_address <= (others => '0');
                ram_data    <= (others => '0');
            elsif valid = '1' and packet(3 downto 0) = HEADER then
                if PARITY_CHECK and not check_ok(packet) then
                    error <= '1';
                else
                    ram_en      <= '1';
                    ram_address <= packet(11 downto 4);
                    ram_data    <= packet(27 downto 12);
                end if;
            end if;
        end if;
    end process;
end architecture;
