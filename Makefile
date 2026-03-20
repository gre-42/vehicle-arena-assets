.PHONY: build run run_dev test compress_to_tmp

SOURCE_DIR ?= ../vehicle-arena
CMAKE_BUILD_TYPE ?= RelWithDebInfo
BIN_DIR ?= $(SOURCE_DIR)/VehicleArena/U$(CMAKE_BUILD_TYPE)/Bin

SOURCE_DIRS ?= ../MGame_Github/data;../MGame_Extra
DEST_DATA_DIR ?= /tmp/compressed
ASSET_DIRS ?= assets
COMPRESS_FLAGS ?=
COMPRESS_CONFIG ?= assets/compression.json
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

build:
	make build -C $(SOURCE_DIR)/VehicleArena CMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)

build_asan:
	make build_asan -C $(SOURCE_DIR)/VehicleArena CMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)

run:
	ENABLE_OSM_MAP_CACHE=0 \
	"$(BIN_DIR)/render_scene_file" \
		"$(ASSET_DIRS)" \
		assets/levels/main/main.scn.json \
		--app_reldir .vehicle_arena \
		--print_render_residual_time \
		--nsamples_msaa 2 \
		--show_mouse_cursor \
		--windowed_width 1500 \
		--windowed_height 900 \
		--check_gl_errors $(REMOTE_ARGS) $(RUN_ARGS)

run_dev: build
	ENABLE_OSM_MAP_CACHE=0 \
	gdb -ex="catch throw" --ex=r --args "$(BIN_DIR)/render_scene_file" \
		"$(ASSET_DIRS)" \
		assets/levels/main/main.scn.json \
		--app_reldir .vehicle_arena \
		--print_render_residual_time \
		--print_physics_residual_time \
		--nsamples_msaa 2 \
		--show_mouse_cursor \
		--windowed_width 1500 \
		--windowed_height 900 \
		--devel_mode \
		--check_gl_errors $(REMOTE_ARGS) $(RUN_ARGS)

run_tsan:
	OMP_NUM_THREADS=1 \
	TSAN_OPTIONS="second_deadlock_stack=1 suppressions=$(SOURCE_DIR)/suppressions.txt" \
		"$(BIN_DIR)/render_scene_file" \
		"$(ASSET_DIRS)" \
		assets/levels/main/main.scn.json \
		--app_reldir .vehicle_arena \
		--print_render_residual_time \
		--print_physics_residual_time \
		--nsamples_msaa 2 \
		--show_mouse_cursor \
		--windowed_width 1500 \
		--windowed_height 900 \
		--devel_mode \
		--check_gl_errors $(REMOTE_ARGS) $(RUN_ARGS)

test: build run

compress_to_tmp: build
	"$(BIN_DIR)/compress_images" --source_dirs "$(SOURCE_DIRS)" --dest_dir "$(DEST_DATA_DIR)" $(COMPRESS_FLAGS) --config "$(COMPRESS_CONFIG)"
