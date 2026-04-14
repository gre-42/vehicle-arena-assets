.PHONY: test compress

test: compress
	$(MAKE) test -f Makefile

run:
	$(MAKE) run -f Makefile

compress:
	$(MAKE) compress
	$(MAKE) compress \
		SOURCE_DIRS="/media/kl/Acer/Daten/MyPrograms/MGame_Private" \
		COMPRESS_CONFIGS=compressed.private=compression.private.json
