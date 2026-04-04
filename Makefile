.PHONY: build run run_dev test compress_to_tmp pack_snap flame_graph

BUILD_TARGET ?= build
SOURCE_DIR ?= ../vehicle-arena
export CMAKE_BUILD_TYPE ?= RelWithDebInfo
BUILD_PREFIX ?= U
BIN_DIR ?= $(SOURCE_DIR)/VehicleArena/$(BUILD_PREFIX)U$(CMAKE_BUILD_TYPE)/Bin

SOURCE_DIRS ?= ../MGame_Github/data;../MGame_Extra
DEST_DATA_DIR ?= /tmp/compressed
ASSET_DIRS ?= assets
COMPRESS_FLAGS ?=
COMPRESS_CONFIGS ?= $(shell echo "             \
assets/compression.json;                       \
assets/compression.arena.json;                 \
assets/compression.arena_humans.json;          \
assets/compression.race_track0.json;           \
assets/compression.nyc.json;                   \
assets/compression.nyc_td0.json" | sed "s/ //g")
RUN_ARGS ?=
REMOTE_ARGS = $(shell                          \
    if [ "$(REMOTE_ROLE)" = server ]; then     \
        echo --remote_site_id 42               \
         --remote_role server                  \
         --remote_ip 127.0.0.1                 \
         --remote_port 8042;                   \
    elif [ "$(REMOTE_ROLE)" = client ]; then   \
        echo --remote_site_id 43               \
         --remote_role client                  \
         --remote_ip 127.0.0.1                 \
         --remote_port 8042;                   \
    fi                                         \
    )
GDB_ARGS = $(shell                                  \
    if [ "$(GDB)" != 0 ]; then                       \
        echo "gdb -ex='catch throw' -ex=r --args";  \
    fi                                              \
    )
SHOW_MOUSE_CURSOR_ARGS = $(shell         \
    if [ "$(CURSOR)" != 0 ]; then   \
        echo --show_mouse_cursor;   \
    fi                              \
    )
PERF_ARGS = $(shell                                \
    if [ "$(PERF)" = 1 ]; then                     \
        echo sudo -E perf record -F 99 -a -g --;   \
    fi                                             \
    )
PRINT_MATERIALS_ARGS = $(shell             \
    if [ "$(PMAT)" = 1 ]; then             \
        echo --print_rendered_materials;   \
    fi                                     \
    )
CHK_ARGS = $(shell                         \
    if [ "$(CHK)" = 1 ]; then              \
        echo --check_gl_errors;            \
    fi                                     \
    )
OMP_ENV = $(shell                 \
    if [ "$(OMP)" = 0 ]; then     \
        echo OMP_NUM_THREADS=1;   \
    fi                            \
    )

CACHE ?= 0

build:
	$(MAKE) $(BUILD_TARGET) -C $(SOURCE_DIR)/VehicleArena

run:
	$(OMP_ENV) \
	ENABLE_OSM_MAP_CACHE=$(CACHE) \
	$(PERF_ARGS) $(GDB_ARGS) "$(BIN_DIR)/render_scene_file" \
		"$(ASSET_DIRS)" \
		assets/levels/main/main.scn.json \
		--app_reldir .vehicle_arena \
		--print_render_residual_time \
		--nsamples_msaa 2 \
		$(SHOW_MOUSE_CURSOR_ARGS) \
		$(PRINT_MATERIALS_ARGS) \
		--windowed_width 1500 \
		--windowed_height 900 \
		$(CHK_ARGS) $(REMOTE_ARGS) $(RUN_ARGS)

run_tsan:
	OMP_NUM_THREADS=1 \
	TSAN_OPTIONS="second_deadlock_stack=1 suppressions=$(SOURCE_DIR)/suppressions.txt" \
	ENABLE_OSM_MAP_CACHE=$(CACHE) \
	$(PERF_ARGS) $(GDB_ARGS) "$(BIN_DIR)/render_scene_file" \
		"$(ASSET_DIRS)" \
		assets/levels/main/main.scn.json \
		--app_reldir .vehicle_arena \
		--print_render_residual_time \
		--print_physics_residual_time \
		--nsamples_msaa 2 \
		$(SHOW_MOUSE_CURSOR_ARGS) \
		$(PRINT_MATERIALS_ARGS) \
		--windowed_width 1500 \
		--windowed_height 900 \
		--devel_mode \
		$(CHK_ARGS) $(REMOTE_ARGS) $(RUN_ARGS)

test: build compress_to_tmp run

compress_to_tmp:
	$(PERF_ARGS) $(GDB_ARGS) "$(BIN_DIR)/compress_images" --source_dirs "$(SOURCE_DIRS)" --dest_dir "$(DEST_DATA_DIR)" $(COMPRESS_FLAGS) --configs "$(COMPRESS_CONFIGS)"

pack_snap:
	$(MAKE) build BUILD_TARGET="recastnavigation build" CMAKE_BUILD_TYPE=Release BUILD_PREFIX=L GDB=0
	rsync --archive "$(SOURCE_DIR)/VehicleArena/LURelease/Bin/" Bin
	rsync --archive \
		--include='*.so' \
		--include='*.so.?' \
		--include='*.so.?.?.?' \
		--exclude='*' \
		"$(SOURCE_DIR)/VehicleArena/LURelease/Lib/" \
		"$(SOURCE_DIR)/VehicleArena/RecastBuild/DebugUtils/" \
		"$(SOURCE_DIR)/VehicleArena/RecastBuild/Detour/" \
		"$(SOURCE_DIR)/VehicleArena/RecastBuild/Recast/" \
		Lib
	$(MAKE) -f Makefile.user compress_to_tmp DEST_DATA_DIR=compressed CMAKE_BUILD_TYPE=Release BUILD_PREFIX=L GDB=0
	snapcraft pack

flame_graph:
	sudo perf script | stackcollapse-perf.pl > out.perf-folded
	flamegraph.pl out.perf-folded > perf.svg
