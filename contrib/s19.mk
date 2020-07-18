

ifeq (_$(COLS)_,__)
	COLS = 32
endif

$(TARGET).s19: $(TARGET).bin
	@Bin2S19 -c $(COLS) -b $(FLASH_START) -f $(TARGET).bin -z $(FLASH_SIZE) -s >$(TARGET).s19

