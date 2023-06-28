# be-wozmon
Ben Eater 6502 WozMon

This project is based on the 6502 instruction videos from Ben Eater. Taking it one step at a time until a complete configuration which comes close to the Apple I computer. With this configuration you can burn an Eprom that holds the Steve Wozniak monitor program. A legendary tool that allows you to run programs on the BE 6502 computer. You interact with the machine using a serial terminal from any OS.
This project also includes the name of the program and starting address of WozMon. This is why it won't start at `$FF00` but instead from `$C005`

## Compiling be_wozmon_lcd.s

I have used `vasm v1.81`. If you stay close to this version you should survive.

```
vasm6502_oldstyle -Fbin -dotdir -wdc02 ./be_wozmon_lcd.s
```

> This will result in a binary called `a.out`

## Burning the Eprom

For this I have used and XG ecu Pro USB mountable burner (http://www.xgecu.com)[Eprom programmer]. To burn I have used `minipro` (v0.6) like so;

```
minipro -p AT28C256 -w a.out -s
```

Then after the chip has been burned, plug it in and reset it with a serial monitor connected (19200 baud, 8-N-1) you will see a prompt.

```
--<<(( BE WozMon at $C005 ))>>--  
\  
```

## Running a program

From the original Apple-1 Operation manual use the following modified test program:

```
0:A9 0 AA 20 39 C1 E8 8A 4C 2 0
```

and then run it

```
R
```

Have fun! And don't forget to join me in becoming a Patreon to Ben Eater as a gratitude to his hard labour. I promis you, you will love his work!
