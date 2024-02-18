----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- MEGA65 main file that contains the whole machine
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.globals.all;
use work.types_pkg.all;
use work.video_modes_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity MEGA65_Core is
port (
   CLK                     : in  std_logic;              -- 100 MHz clock
   RESET_M2M_N             : in  std_logic;              -- Debounced system reset in system clock domain

   -- Share clock and reset with the framework
   main_clk_o              : out std_logic;              -- Core main clock - 12 Mhz
   main_rst_o              : out std_logic;              -- reset, synchronized
   
   clk24_clk_o             : out std_logic;              -- 24 Mhz
   clk24_rst_o             : out std_logic;              -- reset, synchronized
   
   video_clk_o             : out std_logic;              -- video clock - 48 Mhz
   video_rst_o             : out std_logic;              -- reset, synchronized

   --------------------------------------------------------------------------------------------------------
   -- QNICE Clock Domain
   --------------------------------------------------------------------------------------------------------

   -- Get QNICE clock from the framework: for the vdrives as well as for RAMs and ROMs
   qnice_clk_i             : in  std_logic;
   qnice_rst_i             : in  std_logic;

   -- Video and audio mode control
   qnice_dvi_o             : out std_logic;              -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_video_mode_o      : out natural range 0 to 3;   -- HDMI 1280x720 @ 50 Hz resolution = mode 0, 1280x720 @ 60 Hz resolution = mode 1, PAL 576p in 4:3 and 5:4 are modes 2 and 3
   qnice_scandoubler_o     : out std_logic;              -- 0 = no scandoubler, 1 = scandoubler
   qnice_audio_mute_o      : out std_logic;
   qnice_audio_filter_o    : out std_logic;
   qnice_zoom_crop_o       : out std_logic;
   qnice_ascal_mode_o      : out std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_o : out std_logic;
   qnice_ascal_triplebuf_o : out std_logic;
   qnice_retro15kHz_o      : out std_logic;              -- 0 = normal frequency, 1 = retro 15 kHz frequency
   qnice_csync_o           : out std_logic;              -- 0 = normal HS/VS, 1 = Composite Sync  
   qnice_osm_cfg_scaling_o : out std_logic_vector(8 downto 0);

   -- Flip joystick ports
   qnice_flip_joyports_o   : out std_logic;

   -- On-Screen-Menu selections
   qnice_osm_control_i     : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   qnice_gp_reg_i          : in  std_logic_vector(255 downto 0);

   -- Core-specific devices
   qnice_dev_id_i          : in  std_logic_vector(15 downto 0);
   qnice_dev_addr_i        : in  std_logic_vector(27 downto 0);
   qnice_dev_data_i        : in  std_logic_vector(15 downto 0);
   qnice_dev_data_o        : out std_logic_vector(15 downto 0);
   qnice_dev_ce_i          : in  std_logic;
   qnice_dev_we_i          : in  std_logic;
   qnice_dev_wait_o        : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- Core Clock Domain
   --------------------------------------------------------------------------------------------------------

   -- M2M's reset manager provides 2 signals:
   --    m2m:   Reset the whole machine: Core and Framework
   --    core:  Only reset the core
   main_reset_m2m_i        : in  std_logic;
   main_reset_core_i       : in  std_logic;

   main_pause_core_i       : in  std_logic;

   -- Video output
   video_ce_o              : out std_logic;
   video_ce_ovl_o          : out std_logic;
   video_red_o             : out std_logic_vector(7 downto 0);
   video_green_o           : out std_logic_vector(7 downto 0);
   video_blue_o            : out std_logic_vector(7 downto 0);
   video_vs_o              : out std_logic;
   video_hs_o              : out std_logic;
   video_hblank_o          : out std_logic;
   video_vblank_o          : out std_logic;
  
   -- Audio output (Signed PCM)
   main_audio_left_o       : out signed(15 downto 0);
   main_audio_right_o      : out signed(15 downto 0);

   -- M2M Keyboard interface (incl. drive led)
   main_kb_key_num_i       : in  integer range 0 to 79;  -- cycles through all MEGA65 keys
   main_kb_key_pressed_n_i : in  std_logic;              -- low active: debounced feedback: is kb_key_num_i pressed right now?
   main_power_led_o        : out std_logic;
   main_power_led_col_o    : out std_logic_vector(23 downto 0);    
   main_drive_led_o        : out std_logic;
   main_drive_led_col_o    : out std_logic_vector(23 downto 0);

   -- Joysticks input
   main_joy_1_up_n_i       : in  std_logic;
   main_joy_1_down_n_i     : in  std_logic;
   main_joy_1_left_n_i     : in  std_logic;
   main_joy_1_right_n_i    : in  std_logic;
   main_joy_1_fire_n_i     : in  std_logic;

   main_joy_2_up_n_i       : in  std_logic;
   main_joy_2_down_n_i     : in  std_logic;
   main_joy_2_left_n_i     : in  std_logic;
   main_joy_2_right_n_i    : in  std_logic;
   main_joy_2_fire_n_i     : in  std_logic;

   main_pot1_x_i           : in  std_logic_vector(7 downto 0);
   main_pot1_y_i           : in  std_logic_vector(7 downto 0);
   main_pot2_x_i           : in  std_logic_vector(7 downto 0);
   main_pot2_y_i           : in  std_logic_vector(7 downto 0);

   -- On-Screen-Menu selections
   main_osm_control_i      : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register converted to main clock domain
   main_qnice_gp_reg_i     : in  std_logic_vector(255 downto 0);

   --------------------------------------------------------------------------------------------------------
   -- Provide HyperRAM to core (in HyperRAM clock domain)
   --------------------------------------------------------------------------------------------------------

   hr_clk_i                : in  std_logic;
   hr_rst_i                : in  std_logic;
   hr_core_write_o         : out std_logic := '0';
   hr_core_read_o          : out std_logic := '0';
   hr_core_address_o       : out std_logic_vector(31 downto 0) := (others => '0');
   hr_core_writedata_o     : out std_logic_vector(15 downto 0) := (others => '0');
   hr_core_byteenable_o    : out std_logic_vector( 1 downto 0) := (others => '0');
   hr_core_burstcount_o    : out std_logic_vector( 7 downto 0) := (others => '0');
   hr_core_readdata_i      : in  std_logic_vector(15 downto 0);
   hr_core_readdatavalid_i : in  std_logic;
   hr_core_waitrequest_i   : in  std_logic;
   hr_high_i               : in  std_logic;  -- Core is too fast
   hr_low_i                : in  std_logic   -- Core is too slow
);
end entity MEGA65_Core;

architecture synthesis of MEGA65_Core is

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------


signal clk12_clk           : std_logic; --
signal clk12_rst           : std_logic;

signal clk24_clk           : std_logic;
signal clk24_rst           : std_logic;

signal clk48_clk           : std_logic;               
signal clk48_rst           : std_logic;

---------------------------------------------------------------------------------------------
-- main_clk (MiSTer core's clock)
---------------------------------------------------------------------------------------------

-- Unprocessed video output from the Galaga core
signal main_video_red      : std_logic_vector(3 downto 0);   
signal main_video_green    : std_logic_vector(3 downto 0);
signal main_video_blue     : std_logic_vector(3 downto 0);
signal main_video_vs       : std_logic;
signal main_video_hs       : std_logic;
signal main_video_hblank   : std_logic;
signal main_video_vblank   : std_logic;

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

constant C_MENU_OSMPAUSE      : natural := 2;  
constant C_MENU_OSMDIM        : natural := 3;
constant C_FLIP_JOYS          : natural := 4;
constant C_MENU_CRT_EMULATION : natural := 8;
constant C_MENU_HDMI_16_9_50  : natural := 12;
constant C_MENU_HDMI_16_9_60  : natural := 13;
constant C_MENU_HDMI_4_3_50   : natural := 14;
constant C_MENU_HDMI_5_4_50   : natural := 15;

constant C_MENU_VGA_STD       : natural := 21;
constant C_MENU_VGA_15KHZHSVS : natural := 25;
constant C_MENU_VGA_15KHZCS   : natural := 26;

constant C_MENU_MIDWAY        : natural := 32;
constant C_MENU_NAMCO         : natural := 33;

-- Midway DIPs
-- Dipswitch B
constant C_MENU_MIDWAY_DSWB_0 : natural := 38;
constant C_MENU_MIDWAY_DSWB_1 : natural := 39;
constant C_MENU_MIDWAY_DSWB_2 : natural := 40;
constant C_MENU_MIDWAY_DSWB_3 : natural := 41;
constant C_MENU_MIDWAY_DSWB_4 : natural := 42;
constant C_MENU_MIDWAY_DSWB_5 : natural := 43;
constant C_MENU_MIDWAY_DSWB_6 : natural := 44;
constant C_MENU_MIDWAY_DSWB_7 : natural := 45;

-- Dipswitch A
constant C_MENU_MIDWAY_DSWA_0 : natural := 47;
constant C_MENU_MIDWAY_DSWA_1 : natural := 48;
constant C_MENU_MIDWAY_DSWA_2 : natural := 49;
constant C_MENU_MIDWAY_DSWA_3 : natural := 50;
constant C_MENU_MIDWAY_DSWA_4 : natural := 51;
constant C_MENU_MIDWAY_DSWA_5 : natural := 52;
constant C_MENU_MIDWAY_DSWA_6 : natural := 53;
constant C_MENU_MIDWAY_DSWA_7 : natural := 54;


-- Namco DIPs
-- Dipswitch B
constant C_MENU_NAMCO_DSWB_0  : natural := 60;
constant C_MENU_NAMCO_DSWB_1  : natural := 61;
constant C_MENU_NAMCO_DSWB_2  : natural := 62;
constant C_MENU_NAMCO_DSWB_3  : natural := 63;
constant C_MENU_NAMCO_DSWB_4  : natural := 64;
constant C_MENU_NAMCO_DSWB_5  : natural := 65;
constant C_MENU_NAMCO_DSWB_6  : natural := 66;
constant C_MENU_NAMCO_DSWB_7  : natural := 67;

-- Dipswitch A
constant C_MENU_NAMCO_DSWA_0  : natural := 69;
constant C_MENU_NAMCO_DSWA_1  : natural := 70;
constant C_MENU_NAMCO_DSWA_2  : natural := 71;
constant C_MENU_NAMCO_DSWA_3  : natural := 72;
constant C_MENU_NAMCO_DSWA_4  : natural := 73;
constant C_MENU_NAMCO_DSWA_5  : natural := 74;
constant C_MENU_NAMCO_DSWA_6  : natural := 75;
constant C_MENU_NAMCO_DSWA_7  : natural := 76;


-- Galaga specific video processing
signal div          : std_logic_vector(1 downto 0);
signal dim_video    : std_logic;
signal dsw_a_i      : std_logic_vector(7 downto 0);
signal dsw_b_i      : std_logic_vector(7 downto 0);

signal video_ce     : std_logic;
signal video_red    : std_logic_vector(7 downto 0);
signal video_green  : std_logic_vector(7 downto 0);
signal video_blue   : std_logic_vector(7 downto 0);
signal video_vs     : std_logic;
signal video_hs     : std_logic;
signal video_vblank : std_logic;
signal video_hblank : std_logic;
signal video_de     : std_logic;

-- Output from screen_rotate
signal ddram_addr       : std_logic_vector(28 downto 0);
signal ddram_data       : std_logic_vector(63 downto 0);
signal ddram_be         : std_logic_vector( 7 downto 0);
signal ddram_we         : std_logic;

-- ROM devices for Galaga
signal qnice_dn_addr    : std_logic_vector(18 downto 0);
signal qnice_dn_data    : std_logic_vector(7 downto 0);
signal qnice_dn_wr      : std_logic;


begin

   -- Configure the LEDs:
   -- Power led on and green, drive led always off
   main_power_led_o       <= '1';
   main_power_led_col_o   <= x"00FF00";
   main_drive_led_o       <= '0';
   main_drive_led_col_o   <= x"00FF00"; 

   -- MMCME2_ADV clock generators:
   clk_gen : entity work.clk
      port map (
         sys_clk_i         => CLK,             -- expects 100 MHz
         sys_rstn_i        => RESET_M2M_N,     -- Asynchronous, asserted low
         
         main_clk_o        => clk12_clk,        -- 12 Mhz main clock
         main_rst_o        => clk12_rst,        -- reset, synchronized
         
         clk_24_o          => clk24_clk,        -- 24 Mhz clock
         clk_24_rst_o      => clk24_rst,        -- reset, synchronized
         
         clk48_clk_o       => clk48_clk,        -- 48 MHz
         clk48_rst_o       => clk48_rst         -- reset, synchronized

      ); -- clk_gen
      
 
   main_clk_o       <= clk12_clk;
   main_rst_o       <= clk12_rst;
   
   clk24_clk_o      <= clk24_clk;
   clk24_rst_o      <= clk24_rst;
   
   video_clk_o      <= clk48_clk;
   video_rst_o      <= clk48_rst;
   
   video_red_o      <= video_red;
   video_green_o    <= video_green;
   video_blue_o     <= video_blue;
   video_vs_o       <= video_vs;
   video_hs_o       <= video_hs;
   video_hblank_o   <= video_hblank;
   video_vblank_o   <= video_vblank;
   video_ce_o       <= video_ce;       
   
   dsw_a_i <= main_osm_control_i(C_MENU_MIDWAY_DSWA_7) &
              main_osm_control_i(C_MENU_MIDWAY_DSWA_6) &
              main_osm_control_i(C_MENU_MIDWAY_DSWA_5) &
              main_osm_control_i(C_MENU_MIDWAY_DSWA_4) &
              main_osm_control_i(C_MENU_MIDWAY_DSWA_3) &
              main_osm_control_i(C_MENU_MIDWAY_DSWA_2) &
              main_osm_control_i(C_MENU_MIDWAY_DSWA_1) &
              main_osm_control_i(C_MENU_MIDWAY_DSWA_0);  
   
   dsw_b_i <= main_osm_control_i(C_MENU_MIDWAY_DSWB_7) &
              main_osm_control_i(C_MENU_MIDWAY_DSWB_6) &
              main_osm_control_i(C_MENU_MIDWAY_DSWB_5) &
              main_osm_control_i(C_MENU_MIDWAY_DSWB_4) &
              main_osm_control_i(C_MENU_MIDWAY_DSWB_3) &
              main_osm_control_i(C_MENU_MIDWAY_DSWB_2) &
              main_osm_control_i(C_MENU_MIDWAY_DSWB_1) &
              main_osm_control_i(C_MENU_MIDWAY_DSWB_0);
   
            
   ---------------------------------------------------------------------------------------------
   -- main_clk (MiSTer core's clock)
   ---------------------------------------------------------------------------------------------

   -- main.vhd contains the actual MiSTer core
   i_main : entity work.main
      generic map (
         G_VDNUM              => C_VDNUM
         
      )
      port map (
         clk_main_i           => clk12_clk,
         reset_soft_i         => main_reset_core_i,
         reset_hard_i         => main_reset_m2m_i,
         pause_i              => main_pause_core_i and main_osm_control_i(C_MENU_OSMPAUSE),
         dim_video_o          => dim_video,
         clk_main_speed_i     => CORE_CLK_SPEED,
         
         -- Video output
         -- This is PAL 720x576 @ 50 Hz (pixel clock 27 MHz), but synchronized to main_clk (54 MHz).
         video_ce_o           => open,
         video_ce_ovl_o       => open,
         video_red_o          => main_video_red,
         video_green_o        => main_video_green,
         video_blue_o         => main_video_blue,
         video_vs_o           => main_video_vs,
         video_hs_o           => main_video_hs,
         video_hblank_o       => main_video_hblank,
         video_vblank_o       => main_video_vblank,
         
         -- Audio output (PCM format, signed values)
         audio_left_o         => main_audio_left_o,
         audio_right_o        => main_audio_right_o,

         -- M2M Keyboard interface
         kb_key_num_i         => main_kb_key_num_i,
         kb_key_pressed_n_i   => main_kb_key_pressed_n_i,

         -- MEGA65 joysticks and paddles/mouse/potentiometers
         joy_1_up_n_i         => main_joy_1_up_n_i ,
         joy_1_down_n_i       => main_joy_1_down_n_i,
         joy_1_left_n_i       => main_joy_1_left_n_i,
         joy_1_right_n_i      => main_joy_1_right_n_i,
         joy_1_fire_n_i       => main_joy_1_fire_n_i,
         joy_2_up_n_i         => main_joy_2_up_n_i,
         joy_2_down_n_i       => main_joy_2_down_n_i,
         joy_2_left_n_i       => main_joy_2_left_n_i,
         joy_2_right_n_i      => main_joy_2_right_n_i,
         joy_2_fire_n_i       => main_joy_2_fire_n_i,
         pot1_x_i             => main_pot1_x_i,
         pot1_y_i             => main_pot1_y_i,
         pot2_x_i             => main_pot2_x_i,
         pot2_y_i             => main_pot2_y_i,

         dn_clk_i             => qnice_clk_i,
         dn_addr_i            => qnice_dn_addr,
         dn_data_i            => qnice_dn_data,
         dn_wr_i              => qnice_dn_wr,

         osm_control_i        => main_osm_control_i,
         dsw_a_i              => dsw_a_i,
         dsw_b_i              => dsw_b_i
      ); -- i_main


    process (clk24_clk) -- 24 Mhz
    begin
        video_ce_ovl_o <= '0';
        if rising_edge(clk24_clk) then
             div <= std_logic_vector(unsigned(div) + 1);
             video_ce <= not div(0); -- 12 Mhz Pixel clock
             video_ce_ovl_o <= '1';  -- OSM clock.
         end if;
    end process;
    
    process (clk48_clk) -- 48 MHz
    begin
        if rising_edge(clk48_clk) then
            video_red   <= main_video_red   & main_video_red;
            video_green <= main_video_green & main_video_green;
            video_blue  <= main_video_blue  & main_video_blue;
               
            video_hs     <= main_video_hs;
            video_vs     <= main_video_vs;
            video_hblank <= not main_video_hblank;
            video_vblank <= not main_video_vblank;
            video_de     <= not (main_video_hblank or main_video_vblank);
        end if;
    end process;
    
   ---------------------------------------------------------------------------------------------
   -- Audio and video settings (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   -- Due to a discussion on the MEGA65 discord (https://discord.com/channels/719326990221574164/794775503818588200/1039457688020586507)
   -- we decided to choose a naming convention for the PAL modes that might be more intuitive for the end users than it is
   -- for the programmers: "4:3" means "meant to be run on a 4:3 monitor", "5:4 on a 5:4 monitor".
   -- The technical reality is though, that in our "5:4" mode we are actually doing a 4/3 aspect ratio adjustment
   -- while in the 4:3 mode we are outputting a 5:4 image. This is kind of odd, but it seemed that our 4/3 aspect ratio
   -- adjusted image looks best on a 5:4 monitor and the other way round.
   -- Not sure if this will stay forever or if we will come up with a better naming convention.
   qnice_video_mode_o <= 3 when qnice_osm_control_i(C_MENU_HDMI_5_4_50)  = '1' else
                         2 when qnice_osm_control_i(C_MENU_HDMI_4_3_50)  = '1' else
                         1 when qnice_osm_control_i(C_MENU_HDMI_16_9_60) = '1' else
                         0;
   -- qnice_retro15kHz_o: '1', if the output from the core (post-scandoubler) in the retro 15 kHz analog RGB mode.
   --             Hint: Scandoubler off does not automatically mean retro 15 kHz on.
   qnice_scandoubler_o        <= (not qnice_osm_control_i(C_MENU_VGA_15KHZHSVS)) and
                                 (not qnice_osm_control_i(C_MENU_VGA_15KHZCS));   
   qnice_retro15kHz_o <= qnice_osm_control_i(C_MENU_VGA_15KHZHSVS) or qnice_osm_control_i(C_MENU_VGA_15KHZCS);
   qnice_csync_o      <= qnice_osm_control_i(C_MENU_VGA_15KHZCS);

   -- Zoom out the OSM
   qnice_osm_cfg_scaling_o    <= (others => '1');

   -- Use On-Screen-Menu selections to configure several audio and video settings
   -- Video and audio mode control
   qnice_dvi_o                <= '0';                                         -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_audio_mute_o         <= '0';                                         -- audio is not muted
   qnice_audio_filter_o       <= '1';                                         -- 0 = raw audio, 1 = use filters from globals.vhd

   -- ascal filters that are applied while processing the input
   -- 00 : Nearest Neighbour
   -- 01 : Bilinear
   -- 10 : Sharp Bilinear
   -- 11 : Bicubic
   qnice_ascal_mode_o         <= "00";

   -- If polyphase is '1' then the ascal filter mode is ignored and polyphase filters are used instead
   -- @TODO: Right now, the filters are hardcoded in the M2M framework, we need to make them changeable inside m2m-rom.asm
   qnice_ascal_polyphase_o    <= qnice_osm_control_i(C_MENU_CRT_EMULATION);

   -- ascal triple-buffering
   -- @TODO: Right now, the M2M framework only supports OFF, so do not touch until the framework is upgraded
   qnice_ascal_triplebuf_o    <= '0';

   -- Flip joystick ports (i.e. the joystick in port 2 is used as joystick 1 and vice versa)
   qnice_flip_joyports_o      <= qnice_osm_control_i(C_FLIP_JOYS);

   ---------------------------------------------------------------------------------------------
   -- Core specific device handling (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   core_specific_devices : process(all)
   begin
      -- make sure that this is x"EEEE" by default and avoid a register here by having this default value
      qnice_dev_data_o <= x"EEEE";
      qnice_dev_wait_o <= '0';

      -- Default values
      qnice_dn_wr      <= '0';
      qnice_dn_addr    <= (others => '0');
      qnice_dn_data    <= (others => '0');


 -- GnG Capcom
    -- cpu  00000 14000
    -- chr  14000 04000
    -- snd  18000 08000
    -- scr1 20000 08000
    --scr2 28000 08000
    --scr3 30000 08000
    -- ---- 38000 08000
    -- obj1 40000 10000
    -- obj2 50000 10000
    
      case qnice_dev_id_i is
    
        when C_DEV_GNG_CPU_ROM1 => -- 81920 bytes 
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr <= "00" & qnice_dev_addr_i(16 downto 0);         -- 0x0000 - 0x13fff  ( 00 00000000000000000 to 00 10011111111111111 )
              qnice_dn_data <= qnice_dev_data_i(7 downto 0);            
              
        when C_DEV_GNG_CHARS_1 =>  -- 8192 bytes
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr <= "001010" & qnice_dev_addr_i(12 downto 0);     -- 0x14000 -0x15fff  ( 000101 00000000000000 to 000101 01111111111111 )
              qnice_dn_data <= qnice_dev_data_i(7 downto 0); 
              
        when C_DEV_GNG_CHARS_2 =>  -- 8192 bytes
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr <= "001011" & qnice_dev_addr_i(12 downto 0);     -- 0x16000 -0x17fff  ( 000101 10000000000001 to 000101 11111111111111 )
              qnice_dn_data <= qnice_dev_data_i(7 downto 0); 
              
        when C_DEV_GNG_AUDIO  =>  -- 32768 bytes 
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr <= "0011" & qnice_dev_addr_i(14 downto 0);        -- 0x18000 -0x1ffff  ( 00011 000000000000000 to 00011 111111111111111 )
              qnice_dn_data <= qnice_dev_data_i(7 downto 0);    
        
        when C_DEV_GNG_TILE1  =>  -- 32768 bytes 
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr <= "0100" & qnice_dev_addr_i(14 downto 0);        -- 0x20000 -0x27fff  ( 00100 000000000000000 to 00100 111111111111111 )
              qnice_dn_data <= qnice_dev_data_i(7 downto 0);
             
        when C_DEV_GNG_TILE2  =>  -- 32768 bytes 
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr <= "0101" & qnice_dev_addr_i(14 downto 0);        -- 0x28000 -0x27fff  ( 00101 00000000000000 to 00101 111111111111111 )
              qnice_dn_data <= qnice_dev_data_i(7 downto 0);
              
        when C_DEV_GNG_TILE3  =>  -- 32768 bytes 
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr <= "0110" & qnice_dev_addr_i(14 downto 0);        -- 0x30000 -0x37fff  ( 00110 000000000000000 to 00110 111111111111111 )
              qnice_dn_data <= qnice_dev_data_i(7 downto 0);
              
        when C_DEV_GNG_TILE4  =>  -- 32768 bytes 
              qnice_dn_wr   <= qnice_dev_ce_i and qnice_dev_we_i;
              qnice_dn_addr <= "0111" & qnice_dev_addr_i(14 downto 0);        -- 0x38000 -0x3ffff  ( 00111 000000000000000 to 00111111111111111111 )
              qnice_dn_data <= qnice_dev_data_i(7 downto 0);
            
         when others => null;
      end case;

      if qnice_rst_i = '1' then
         qnice_dn_wr <= '0';
      end if;
   end process core_specific_devices;

   ---------------------------------------------------------------------------------------------
   -- Dual Clocks
   ---------------------------------------------------------------------------------------------

   -- Put your dual-clock devices such as RAMs and ROMs here
   --
   -- Use the M2M framework's official RAM/ROM: dualport_2clk_ram
   -- and make sure that the you configure the port that works with QNICE as a falling edge
   -- by setting G_FALLING_A or G_FALLING_B (depending on which port you use) to true.


end architecture synthesis;

