--
-- OBS Zoom to Mouse（中文汉化版）
-- 将“显示采集”源缩放以聚焦鼠标位置的 OBS Lua 脚本
-- 原作版权 (c) BlankSourceCode.  All rights reserved.
-- 汉化：ChatGPT（仅翻译界面和提示文本，不改动功能）
--

local obs = obslua
local ffi = require("ffi")
local VERSION = "1.2.1"
local CROP_FILTER_NAME = "obs-zoom-to-mouse-crop"

local source_name = ""
local source = nil
local sceneitem = nil
local sceneitem_transform = nil
local sceneitem_transform_orig = nil
local sceneitem_crop = nil
local sceneitem_crop_orig = nil
local crop_filter = nil
local crop_filter_temp = nil
local crop_filter_settings = nil
local crop_filter_info_orig = { x = 0, y = 0, w = 0, h = 0 }
local crop_filter_info = { x = 0, y = 0, w = 0, h = 0 }
local monitor_info = nil
local zoom_info = {
    source_size = { width = 0, height = 0 },
    source_crop = { x = 0, y = 0, w = 0, h = 0 },
    source_crop_filter = { x = 0, y = 0, w = 0, h = 0 },
    zoom_to = 2
}
local zoom_time = 0
local zoom_target = nil
local locked_center = nil
local locked_last_pos = nil
local hotkey_zoom_id = nil
local hotkey_follow_id = nil
local is_timer_running = false

local win_point = nil
local x11_display = nil
local x11_root = nil
local x11_mouse = nil
local osx_lib = nil
local osx_nsevent = nil
local osx_mouse_location = nil

local use_auto_follow_mouse = true
local use_follow_outside_bounds = false
local is_following_mouse = false
local follow_speed = 0.1
local follow_border = 0
local follow_safezone_sensitivity = 10
local use_follow_auto_lock = false
local zoom_value = 2
local zoom_speed = 0.1
local allow_all_sources = false
local use_monitor_override = false
local monitor_override_x = 0
local monitor_override_y = 0
local monitor_override_w = 0
local monitor_override_h = 0
local monitor_override_sx = 0
local monitor_override_sy = 0
local monitor_override_dw = 0
local monitor_override_dh = 0
local debug_logs = false

local ZoomState = {
    None = 0,
    ZoomingIn = 1,
    ZoomingOut = 2,
    ZoomedIn = 3,
}
local zoom_state = ZoomState.None

local version = obs.obs_get_version_string()
local major = tonumber(version:match("^(%d+)")) or 0

-- 为各平台定义鼠标坐标函数
if ffi.os == "Windows" then
    ffi.cdef([[
        typedef int BOOL;
        typedef struct{
            long x;
            long y;
        } POINT, *LPPOINT;
        BOOL GetCursorPos(LPPOINT);
    ]])
    win_point = ffi.new("POINT[1]")
elseif ffi.os == "Linux" then
    ffi.cdef([[
        typedef unsigned long XID;
        typedef XID Window;
        typedef void Display;
        Display* XOpenDisplay(char*);
        XID XDefaultRootWindow(Display *display);
        int XQueryPointer(Display*, Window, Window*, Window*, int*, int*, int*, int*, unsigned int*);
        int XCloseDisplay(Display*);
    ]])

    x11_lib = ffi.load("X11.so.6")
    x11_display = x11_lib.XOpenDisplay(nil)
    if x11_display ~= nil then
        x11_root = x11_lib.XDefaultRootWindow(x11_display)
        x11_mouse = {
            root_win = ffi.new("Window[1]"),
            child_win = ffi.new("Window[1]"),
            root_x = ffi.new("int[1]"),
            root_y = ffi.new("int[1]"),
            win_x = ffi.new("int[1]"),
            win_y = ffi.new("int[1]"),
            mask = ffi.new("unsigned int[1]")
        }
    end
elseif ffi.os == "OSX" then
    ffi.cdef([[
        typedef struct {
            double x;
            double y;
        } CGPoint;
        typedef void* SEL;
        typedef void* id;
        typedef void* Method;

        SEL sel_registerName(const char *str);
        id objc_getClass(const char*);
        Method class_getClassMethod(id cls, SEL name);
        void* method_getImplementation(Method);
        int access(const char *path, int amode);
    ]])

    osx_lib = ffi.load("libobjc")
    if osx_lib ~= nil then
        osx_nsevent = {
            class = osx_lib.objc_getClass("NSEvent"),
            sel = osx_lib.sel_registerName("mouseLocation")
        }
        local method = osx_lib.class_getClassMethod(osx_nsevent.class, osx_nsevent.sel)
        if method ~= nil then
            local imp = osx_lib.method_getImplementation(method)
            osx_mouse_location = ffi.cast("CGPoint(*)(void*, void*)", imp)
        end
    end
end

--- 获取当前鼠标位置
---@return table 鼠标位置
function get_mouse_pos()
    local mouse = { x = 0, y = 0 }

    if ffi.os == "Windows" then
        if win_point and ffi.C.GetCursorPos(win_point) ~= 0 then
            mouse.x = win_point[0].x
            mouse.y = win_point[0].y
        end
    elseif ffi.os == "Linux" then
        if x11_lib ~= nil and x11_display ~= nil and x11_root ~= nil and x11_mouse ~= nil then
            if x11_lib.XQueryPointer(x11_display, x11_root, x11_mouse.root_win, x11_mouse.child_win, x11_mouse.root_x, x11_mouse.root_y, x11_mouse.win_x, x11_mouse.win_y, x11_mouse.mask) ~= 0 then
                mouse.x = tonumber(x11_mouse.win_x[0])
                mouse.y = tonumber(x11_mouse.win_y[0])
            end
        end
    elseif ffi.os == "OSX" then
        if osx_lib ~= nil and osx_nsevent ~= nil and osx_mouse_location ~= nil then
            local point = osx_mouse_location(osx_nsevent.class, osx_nsevent.sel)
            mouse.x = point.x
            if monitor_info ~= nil then
                if monitor_info.display_height > 0 then
                    mouse.y = monitor_info.display_height - point.y
                else
                    mouse.y = monitor_info.height - point.y
                end
            end
        end
    end

    return mouse
end

--- 获取当前平台的显示采集（Display Capture）源信息
function get_dc_info()
    if ffi.os == "Windows" then
        return {
            source_id = "monitor_capture",
            prop_id = "monitor_id",
            prop_type = "string"
        }
    elseif ffi.os == "Linux" then
        return {
            source_id = "xshm_input",
            prop_id = "screen",
            prop_type = "int"
        }
    elseif ffi.os == "OSX" then
        if major > 29 then
            return {
                source_id = "screen_capture",
                prop_id = "display_uuid",
                prop_type = "string"
            }
        else
            return {
                source_id = "display_capture",
                prop_id = "display",
                prop_type = "int"
            }
        end
    end

    return nil
end

--- 向 OBS 脚本日志输出信息（仅在启用调试时）
function log(msg)
    if debug_logs then
        obs.script_log(obs.OBS_LOG_INFO, "[obs-zoom-to-mouse] " .. msg)
    end
end

--- 将 Lua 表格式化为字符串（调试用）
function format_table(tbl, indent)
    if not indent then
        indent = 0
    end

    local str = "{\n"
    for key, value in pairs(tbl) do
        local tabs = string.rep("  ", indent + 1)
        if type(value) == "table" then
            str = str .. tabs .. key .. " = " .. format_table(value, indent + 1) .. ",\n"
        else
            str = str .. tabs .. key .. " = " .. tostring(value) .. ",\n"
        end
    end
    str = str .. string.rep("  ", indent) .. "}"

    return str
end

--- 线性插值
function lerp(v0, v1, t)
    return v0 * (1 - t) + v1 * t;
end

--- 缓入缓出
function ease_in_out(t)
    t = t * 2
    if t < 1 then
        return 0.5 * t * t * t
    else
        t = t - 2
        return 0.5 * (t * t * t + 2)
    end
end

--- 数值截断（限制在最小与最大之间）
function clamp(min, max, value)
    return math.max(min, math.min(max, value))
end

--- 获取显示器（显示采集源）的位置与尺寸，用于计算鼠标相对坐标
---@param source any OBS 源
---@return table|nil monitor_info 显示器信息
function get_monitor_info(source)
    local info = nil

    -- 仅当目标为显示采集且未启用手动覆盖时才进行自动探测
    if is_display_capture(source) and not use_monitor_override then
        local dc_info = get_dc_info()
        if dc_info ~= nil then
            local props = obs.obs_source_properties(source)
            if props ~= nil then
                local monitor_id_prop = obs.obs_properties_get(props, dc_info.prop_id)
                if monitor_id_prop then
                    local found = nil
                    local settings = obs.obs_source_get_settings(source)
                    if settings ~= nil then
                        local to_match
                        if dc_info.prop_type == "string" then
                            to_match = obs.obs_data_get_string(settings, dc_info.prop_id)
                        elseif dc_info.prop_type == "int" then
                            to_match = obs.obs_data_get_int(settings, dc_info.prop_id)
                        end

                        local item_count = obs.obs_property_list_item_count(monitor_id_prop);
                        for i = 0, item_count do
                            local name = obs.obs_property_list_item_name(monitor_id_prop, i)
                            local value
                            if dc_info.prop_type == "string" then
                                value = obs.obs_property_list_item_string(monitor_id_prop, i)
                            elseif dc_info.prop_type == "int" then
                                value = obs.obs_property_list_item_int(monitor_id_prop, i)
                            end

                            if value == to_match then
                                found = name
                                break
                            end
                        end
                        obs.obs_data_release(settings)
                    end

                    -- 说明：OBS 的显示器名称通常形如
                    -- "U2790B: 3840x2160 @ -1920,0 (Primary Monitor)"
                    -- 本处解析该字符串以得到显示器位置与分辨率。
                    if found then
                        log("解析显示器名称: " .. found)
                        local x, y = found:match("(-?%d+),(-?%d+)")
                        local width, height = found:match("(%d+)x(%d+)")

                        info = { x = 0, y = 0, width = 0, height = 0 }
                        info.x = tonumber(x, 10)
                        info.y = tonumber(y, 10)
                        info.width = tonumber(width, 10)
                        info.height = tonumber(height, 10)
                        info.scale_x = 1
                        info.scale_y = 1
                        info.display_width = info.width
                        info.display_height = info.height

                        log("已解析到显示器信息\n" .. format_table(info))

                        if info.width == 0 and info.height == 0 then
                            info = nil
                        end
                    end
                end

                obs.obs_properties_destroy(props)
            end
        end
    end

    if use_monitor_override then
        info = {
            x = monitor_override_x,
            y = monitor_override_y,
            width = monitor_override_w,
            height = monitor_override_h,
            scale_x = monitor_override_sx,
            scale_y = monitor_override_sy,
            display_width = monitor_override_dw,
            display_height = monitor_override_dh
        }
    end

    if not info then
        log("警告：无法自动计算缩放源的位置与大小。\n" ..
            "      请启用“手动设置源位置”，并填写覆盖值。")
    end

    return info
end

--- 检查指定源是否为显示采集源
function is_display_capture(source_to_check)
    if source_to_check ~= nil then
        local dc_info = get_dc_info()
        if dc_info ~= nil then
            if allow_all_sources then
                local source_type = obs.obs_source_get_id(source_to_check)
                if source_type == dc_info.source_id then
                    return true
                end
            else
                return true
            end
        end
    end

    return false
end

--- 释放 sceneitem 并重置数据
function release_sceneitem()
    if is_timer_running then
        obs.timer_remove(on_timer)
        is_timer_running = false
    end

    zoom_state = ZoomState.None

    if sceneitem ~= nil then
        if crop_filter ~= nil and source ~= nil then
            log("已移除缩放裁剪滤镜")
            obs.obs_source_filter_remove(source, crop_filter)
            obs.obs_source_release(crop_filter)
            crop_filter = nil
        end

        if crop_filter_temp ~= nil and source ~= nil then
            log("已移除临时转换裁剪滤镜")
            obs.obs_source_filter_remove(source, crop_filter_temp)
            obs.obs_source_release(crop_filter_temp)
            crop_filter_temp = nil
        end

        if crop_filter_settings ~= nil then
            obs.obs_data_release(crop_filter_settings)
            crop_filter_settings = nil
        end

        if sceneitem_transform_orig ~= nil then
            log("还原变换信息为初始值")
            local vec2 = obs.vec2()
            vec2.x = sceneitem_transform_orig.pos.x
            vec2.y = sceneitem_transform_orig.pos.y
            obs.obs_sceneitem_set_pos(sceneitem, vec2)
            vec2.x = sceneitem_transform_orig.scale.x
            vec2.y = sceneitem_transform_orig.scale.y
            obs.obs_sceneitem_set_scale(sceneitem, vec2)
            obs.obs_sceneitem_set_rot(sceneitem, sceneitem_transform_orig.rot)
            obs.obs_sceneitem_set_alignment(sceneitem, sceneitem_transform_orig.align)
            obs.obs_sceneitem_set_bounds_type(sceneitem, sceneitem_transform_orig.bounds_type)
            obs.obs_sceneitem_set_bounds_alignment(sceneitem, sceneitem_transform_orig.bounds_align)
            vec2.x = sceneitem_transform_orig.bounds.x
            vec2.y = sceneitem_transform_orig.bounds.y
            obs.obs_sceneitem_set_bounds(sceneitem, vec2)
            sceneitem_transform_orig = nil
        end

        if sceneitem_crop_orig ~= nil then
            log("还原裁剪为初始值")
            obs.obs_sceneitem_set_crop(sceneitem, sceneitem_crop_orig)
            sceneitem_crop_orig = nil
        end

        obs.obs_sceneitem_release(sceneitem)
        sceneitem = nil
    end

    if source ~= nil then
        obs.obs_source_release(source)
        source = nil
    end
end

--- 刷新/更新 sceneitem（可选：重新查找）
function refresh_sceneitem(find_newest)
    -- TODO: 在更新时为何要从源名获取尺寸，而不是 sceneitem 的 source
    local source_raw = { width = 0, height = 0 }

    if find_newest then
        release_sceneitem()

        if source_name == "obs-zoom-to-mouse-none" then
            return
        end

        log("在当前场景中查找缩放源 '" .. source_name .. "'")
        if source_name ~= nil then
            source = obs.obs_get_source_by_name(source_name)
            if source ~= nil then
                source_raw.width = obs.obs_source_get_width(source)
                source_raw.height = obs.obs_source_get_height(source)

                local scene_source = obs.obs_frontend_get_current_scene()
                if scene_source ~= nil then
                    local function find_scene_item_by_name(root_scene)
                        local queue = {}
                        table.insert(queue, root_scene)

                        while #queue > 0 do
                            local s = table.remove(queue, 1)
                            log("查找场景中: '" .. obs.obs_source_get_name(obs.obs_scene_get_source(s)) .. "'")

                            local found = obs.obs_scene_find_source(s, source_name)
                            if found ~= nil then
                                log("已找到 sceneitem '" .. source_name .. "'")
                                obs.obs_sceneitem_addref(found)
                                return found
                            end

                            local all_items = obs.obs_scene_enum_items(s)
                            if all_items then
                                for _, item in pairs(all_items) do
                                    local nested = obs.obs_sceneitem_get_source(item)
                                    if nested ~= nil and obs.obs_source_is_scene(nested) then
                                        local nested_scene = obs.obs_scene_from_source(nested)
                                        table.insert(queue, nested_scene)
                                    end
                                end
                                obs.sceneitem_list_release(all_items)
                            end
                        end

                        return nil
                    end

                    local current = obs.obs_scene_from_source(scene_source)
                    sceneitem = find_scene_item_by_name(current)

                    obs.obs_source_release(scene_source)
                end

                if not sceneitem then
                    log("警告：所选源不在当前场景层级中。\n" ..
                        "      请尝试选择其他缩放源或切换场景。")
                    obs.obs_sceneitem_release(sceneitem)
                    obs.obs_source_release(source)

                    sceneitem = nil
                    source = nil
                    return
                end
            end
        end
    end

    if not monitor_info then
        monitor_info = get_monitor_info(source)
    end

    local is_non_display_capture = not is_display_capture(source)
    if is_non_display_capture then
        if not use_monitor_override then
            log("错误：当前缩放源不是“显示采集”。\n" ..
                "      必须启用“手动设置源位置”，并正确填写尺寸与位置覆盖值。")
        end
    end

    if sceneitem ~= nil then
        sceneitem_transform_orig = {}
        sceneitem_transform_orig.pos = obs.vec2()
        obs.obs_sceneitem_get_pos(sceneitem, sceneitem_transform_orig.pos)
        sceneitem_transform_orig.scale = obs.vec2()
        obs.obs_sceneitem_get_scale(sceneitem, sceneitem_transform_orig.scale)
        sceneitem_transform_orig.rot = obs.obs_sceneitem_get_rot(sceneitem)
        sceneitem_transform_orig.align = obs.obs_sceneitem_get_alignment(sceneitem)
        sceneitem_transform_orig.bounds_type = obs.obs_sceneitem_get_bounds_type(sceneitem)
        sceneitem_transform_orig.bounds_align = obs.obs_sceneitem_get_bounds_alignment(sceneitem)
        sceneitem_transform_orig.bounds = obs.vec2()
        obs.obs_sceneitem_get_bounds(sceneitem, sceneitem_transform_orig.bounds)

        sceneitem_crop_orig = obs.obs_sceneitem_crop()
        obs.obs_sceneitem_get_crop(sceneitem, sceneitem_crop_orig)

        sceneitem_transform = {}
        sceneitem_transform.pos = obs.vec2()
        obs.obs_sceneitem_get_pos(sceneitem, sceneitem_transform.pos)
        sceneitem_transform.scale = obs.vec2()
        obs.obs_sceneitem_get_scale(sceneitem, sceneitem_transform.scale)
        sceneitem_transform.rot = obs.obs_sceneitem_get_rot(sceneitem)
        sceneitem_transform.align = obs.obs_sceneitem_get_alignment(sceneitem)
        sceneitem_transform.bounds_type = obs.obs_sceneitem_get_bounds_type(sceneitem)
        sceneitem_transform.bounds_align = obs.obs_sceneitem_get_bounds_alignment(sceneitem)
        sceneitem_transform.bounds = obs.vec2()
        obs.obs_sceneitem_get_bounds(sceneitem, sceneitem_transform.bounds)

        sceneitem_crop = obs.obs_sceneitem_crop()
        obs.obs_sceneitem_get_crop(sceneitem, sceneitem_crop)

        if is_non_display_capture then
            sceneitem_crop_orig.left = 0
            sceneitem_crop_orig.top = 0
            sceneitem_crop_orig.right = 0
            sceneitem_crop_orig.bottom = 0
        end

        if not source then
            log("错误：无法获取 sceneitem 的源 (" .. source_name .. ")")
        end

        local source_width = obs.obs_source_get_base_width(source)
        local source_height = obs.obs_source_get_base_height(source)

        if source_width == 0 then
            source_width = source_raw.width
        end
        if source_height == 0 then
            source_height = source_raw.height
        end

        if source_width == 0 or source_height == 0 then
            log("错误：无法确定源尺寸。\n" ..
                "      请启用“手动设置源位置”，并填写覆盖值。")

            if monitor_info ~= nil then
                source_width = monitor_info.width
                source_height = monitor_info.height
            end
        else
            log("使用源尺寸: " .. source_width .. ", " .. source_height)
        end

        if sceneitem_transform.bounds_type == obs.OBS_BOUNDS_NONE then
            obs.obs_sceneitem_set_bounds_type(sceneitem, obs.OBS_BOUNDS_SCALE_INNER)
            obs.obs_sceneitem_set_bounds_alignment(sceneitem, 5) -- 左上对齐（0 为居中）
            local vec2 = obs.vec2()
            vec2.x = source_width * sceneitem_transform.scale.x
            vec2.y = source_height * sceneitem_transform.scale.y
            obs.obs_sceneitem_set_bounds(sceneitem, vec2)

            log("警告：发现未使用边界框的变换方式，可能导致缩放异常。\n" ..
                "      已自动转换为“适配内侧”的边界框缩放。若有布局问题，请手动设置。")
        end

        -- 获取已存在（且不是本脚本创建的）裁剪滤镜
        zoom_info.source_crop_filter = { x = 0, y = 0, w = 0, h = 0 }
        local found_crop_filter = false
        local filters = obs.obs_source_enum_filters(source)
        if filters ~= nil then
            for k, v in pairs(filters) do
                local id = obs.obs_source_get_id(v)
                if id == "crop_filter" then
                    local name = obs.obs_source_get_name(v)
                    if name ~= CROP_FILTER_NAME and name ~= "temp_" .. CROP_FILTER_NAME then
                        found_crop_filter = true
                        local settings = obs.obs_source_get_settings(v)
                        if settings ~= nil then
                            if not obs.obs_data_get_bool(settings, "relative") then
                                zoom_info.source_crop_filter.x =
                                    zoom_info.source_crop_filter.x + obs.obs_data_get_int(settings, "left")
                                zoom_info.source_crop_filter.y =
                                    zoom_info.source_crop_filter.y + obs.obs_data_get_int(settings, "top")
                                zoom_info.source_crop_filter.w =
                                    zoom_info.source_crop_filter.w + obs.obs_data_get_int(settings, "cx")
                                zoom_info.source_crop_filter.h =
                                    zoom_info.source_crop_filter.h + obs.obs_data_get_int(settings, "cy")
                                log("检测到已有相对裁剪/填充滤镜(" ..
                                    name ..
                                    ")，应用设置 " .. format_table(zoom_info.source_crop_filter))
                            else
                                log("警告：检测到非相对裁剪/填充滤镜(" .. name .. ")。\n" ..
                                    "      这可能导致缩放异常，建议改为相对模式。")
                            end
                            obs.obs_data_release(settings)
                        end
                    end
                end
            end

            obs.source_list_release(filters)
        end

        -- 若使用了“变换裁剪”，则转换为“裁剪滤镜”，以确保缩放正常
        if not found_crop_filter and (sceneitem_crop_orig.left ~= 0 or sceneitem_crop_orig.top ~= 0 or sceneitem_crop_orig.right ~= 0 or sceneitem_crop_orig.bottom ~= 0) then
            log("创建新的裁剪滤镜以替代变换裁剪")

            source_width = source_width - (sceneitem_crop_orig.left + sceneitem_crop_orig.right)
            source_height = source_height - (sceneitem_crop_orig.top + sceneitem_crop_orig.bottom)

            zoom_info.source_crop_filter.x = sceneitem_crop_orig.left
            zoom_info.source_crop_filter.y = sceneitem_crop_orig.top
            zoom_info.source_crop_filter.w = source_width
            zoom_info.source_crop_filter.h = source_height

            local settings = obs.obs_data_create()
            obs.obs_data_set_bool(settings, "relative", false)
            obs.obs_data_set_int(settings, "left", zoom_info.source_crop_filter.x)
            obs.obs_data_set_int(settings, "top", zoom_info.source_crop_filter.y)
            obs.obs_data_set_int(settings, "cx", zoom_info.source_crop_filter.w)
            obs.obs_data_set_int(settings, "cy", zoom_info.source_crop_filter.h)
            crop_filter_temp = obs.obs_source_create_private("crop_filter", "temp_" .. CROP_FILTER_NAME, settings)
            obs.obs_source_filter_add(source, crop_filter_temp)
            obs.obs_data_release(settings)

            sceneitem_crop.left = 0
            sceneitem_crop.top = 0
            sceneitem_crop.right = 0
            sceneitem_crop.bottom = 0
            obs.obs_sceneitem_set_crop(sceneitem, sceneitem_crop)

            log("警告：检测到“变换裁剪”。已自动转换为“相对裁剪/填充”滤镜。\n" ..
                "      如有问题，建议手动创建裁剪滤镜。")
        elseif found_crop_filter then
            source_width = zoom_info.source_crop_filter.w
            source_height = zoom_info.source_crop_filter.h
        end

        zoom_info.source_size = { width = source_width, height = source_height }
        zoom_info.source_crop = {
            l = sceneitem_crop_orig.left,
            t = sceneitem_crop_orig.top,
            r = sceneitem_crop_orig.right,
            b = sceneitem_crop_orig.bottom
        }

        crop_filter_info_orig = { x = 0, y = 0, w = zoom_info.source_size.width, h = zoom_info.source_size.height }
        crop_filter_info = {
            x = crop_filter_info_orig.x,
            y = crop_filter_info_orig.y,
            w = crop_filter_info_orig.w,
            h = crop_filter_info_orig.h
        }

        crop_filter = obs.obs_source_get_filter_by_name(source, CROP_FILTER_NAME)
        if crop_filter == nil then
            crop_filter_settings = obs.obs_data_create()
            obs.obs_data_set_bool(crop_filter_settings, "relative", false)
            crop_filter = obs.obs_source_create_private("crop_filter", CROP_FILTER_NAME, crop_filter_settings)
            obs.obs_source_filter_add(source, crop_filter)
        else
            crop_filter_settings = obs.obs_source_get_settings(crop_filter)
        end

        obs.obs_source_filter_set_order(source, crop_filter, obs.OBS_ORDER_MOVE_BOTTOM)
        set_crop_settings(crop_filter_info_orig)
    end
end

--- 计算缩放目标位置（基于鼠标点）
function get_target_position(zoom)
    local mouse = get_mouse_pos()

    if monitor_info then
        mouse.x = mouse.x - monitor_info.x
        mouse.y = mouse.y - monitor_info.y
    end

    mouse.x = mouse.x - zoom.source_crop_filter.x
    mouse.y = mouse.y - zoom.source_crop_filter.y

    if monitor_info and monitor_info.scale_x and monitor_info.scale_y then
        mouse.x = mouse.x * monitor_info.scale_x
        mouse.y = mouse.y * monitor_info.scale_y
    end

    local new_size = {
        width = zoom.source_size.width / zoom.zoom_to,
        height = zoom.source_size.height / zoom.zoom_to
    }

    local pos = {
        x = mouse.x - new_size.width * 0.5,
        y = mouse.y - new_size.height * 0.5
    }

    local crop = {
        x = pos.x,
        y = pos.y,
        w = new_size.width,
        h = new_size.height,
    }

    crop.x = math.floor(clamp(0, (zoom.source_size.width - new_size.width), crop.x))
    crop.y = math.floor(clamp(0, (zoom.source_size.height - new_size.height), crop.y))

    return { crop = crop, raw_center = mouse, clamped_center = { x = math.floor(crop.x + crop.w * 0.5), y = math.floor(crop.y + crop.h * 0.5) } }
end

function on_toggle_follow(pressed)
    if pressed then
        is_following_mouse = not is_following_mouse
        log("鼠标跟随已" .. (is_following_mouse and "开启" or "关闭"))

        if is_following_mouse and zoom_state == ZoomState.ZoomedIn then
            if is_timer_running == false then
                is_timer_running = true
                local timer_interval = math.floor(obs.obs_get_frame_interval_ns() / 1000000)
                obs.timer_add(on_timer, timer_interval)
            end
        end
    end
end

function on_toggle_zoom(pressed)
    if pressed then
        if zoom_state == ZoomState.ZoomedIn or zoom_state == ZoomState.None then
            if zoom_state == ZoomState.ZoomedIn then
                log("开始缩小（还原）")
                zoom_state = ZoomState.ZoomingOut
                zoom_time = 0
                locked_center = nil
                locked_last_pos = nil
                zoom_target = { crop = crop_filter_info_orig, c = sceneitem_crop_orig }
                if is_following_mouse then
                    is_following_mouse = false
                    log("已关闭鼠标跟随（因缩小）")
                end
            else
                log("开始放大（缩放到鼠标）")
                zoom_state = ZoomState.ZoomingIn
                zoom_info.zoom_to = zoom_value
                zoom_time = 0
                locked_center = nil
                locked_last_pos = nil
                zoom_target = get_target_position(zoom_info)
            end

            if is_timer_running == false then
                is_timer_running = true
                local timer_interval = math.floor(obs.obs_get_frame_interval_ns() / 1000000)
                obs.timer_add(on_timer, timer_interval)
            end
        end
    end
end

function on_timer()
    if crop_filter_info ~= nil and zoom_target ~= nil then
        zoom_time = zoom_time + zoom_speed

        if zoom_state == ZoomState.ZoomingOut or zoom_state == ZoomState.ZoomingIn then
            if zoom_time <= 1 then
                if zoom_state == ZoomState.ZoomingIn and use_auto_follow_mouse then
                    zoom_target = get_target_position(zoom_info)
                end
                crop_filter_info.x = lerp(crop_filter_info.x, zoom_target.crop.x, ease_in_out(zoom_time))
                crop_filter_info.y = lerp(crop_filter_info.y, zoom_target.crop.y, ease_in_out(zoom_time))
                crop_filter_info.w = lerp(crop_filter_info.w, zoom_target.crop.w, ease_in_out(zoom_time))
                crop_filter_info.h = lerp(crop_filter_info.h, zoom_target.crop.h, ease_in_out(zoom_time))
                set_crop_settings(crop_filter_info)
            end
        else
            if is_following_mouse then
                zoom_target = get_target_position(zoom_info)

                local skip_frame = false
                if not use_follow_outside_bounds then
                    if zoom_target.raw_center.x < zoom_target.crop.x or
                        zoom_target.raw_center.x > zoom_target.crop.x + zoom_target.crop.w or
                        zoom_target.raw_center.y < zoom_target.crop.y or
                        zoom_target.raw_center.y > zoom_target.crop.y + zoom_target.crop.h then
                        skip_frame = true
                    end
                end

                if not skip_frame then
                    if locked_center ~= nil then
                        local diff = {
                            x = zoom_target.raw_center.x - locked_center.x,
                            y = zoom_target.raw_center.y - locked_center.y
                        }

                        local track = {
                            x = zoom_target.crop.w * (0.5 - (follow_border * 0.01)),
                            y = zoom_target.crop.h * (0.5 - (follow_border * 0.01))
                        }

                        if math.abs(diff.x) > track.x or math.abs(diff.y) > track.y then
                            locked_center = nil
                            locked_last_pos = {
                                x = zoom_target.raw_center.x,
                                y = zoom_target.raw_center.y,
                                diff_x = diff.x,
                                diff_y = diff.y
                            }
                            log("已离开锁定区域，恢复跟随")
                        end
                    end

                    if locked_center == nil and (zoom_target.crop.x ~= crop_filter_info.x or zoom_target.crop.y ~= crop_filter_info.y) then
                        crop_filter_info.x = lerp(crop_filter_info.x, zoom_target.crop.x, follow_speed)
                        crop_filter_info.y = lerp(crop_filter_info.y, zoom_target.crop.y, follow_speed)
                        set_crop_settings(crop_filter_info)

                        if is_following_mouse and locked_center == nil and locked_last_pos ~= nil then
                            local diff = {
                                x = math.abs(crop_filter_info.x - zoom_target.crop.x),
                                y = math.abs(crop_filter_info.y - zoom_target.crop.y),
                                auto_x = zoom_target.raw_center.x - locked_last_pos.x,
                                auto_y = zoom_target.raw_center.y - locked_last_pos.y
                            }

                            locked_last_pos.x = zoom_target.raw_center.x
                            locked_last_pos.y = zoom_target.raw_center.y

                            local lock = false
                            if math.abs(locked_last_pos.diff_x) > math.abs(locked_last_pos.diff_y) then
                                if (diff.auto_x < 0 and locked_last_pos.diff_x > 0) or (diff.auto_x > 0 and locked_last_pos.diff_x < 0) then
                                    lock = true
                                end
                            else
                                if (diff.auto_y < 0 and locked_last_pos.diff_y > 0) or (diff.auto_y > 0 and locked_last_pos.diff_y < 0) then
                                    lock = true
                                end
                            end

                            if (lock and use_follow_auto_lock) or (diff.x <= follow_safezone_sensitivity and diff.y <= follow_safezone_sensitivity) then
                                locked_center = {
                                    x = math.floor(crop_filter_info.x + zoom_target.crop.w * 0.5),
                                    y = math.floor(crop_filter_info.y + zoom_target.crop.h * 0.5)
                                }
                                log("检测到鼠标停止移动，已锁定位置： " .. locked_center.x .. ", " .. locked_center.y)
                            end
                        end
                    end
                end
            end
        end

        if zoom_time >= 1 then
            local should_stop_timer = false
            if zoom_state == ZoomState.ZoomingOut then
                log("已缩小完毕")
                zoom_state = ZoomState.None
                should_stop_timer = true
            elseif zoom_state == ZoomState.ZoomingIn then
                log("已放大到鼠标位置")
                zoom_state = ZoomState.ZoomedIn
                should_stop_timer = (not use_auto_follow_mouse) and (not is_following_mouse)

                if use_auto_follow_mouse then
                    is_following_mouse = true
                    log("已自动开启鼠标跟随（因启用“自动跟随鼠标”）")
                end

                if is_following_mouse and follow_border < 50 then
                    zoom_target = get_target_position(zoom_info)
                    locked_center = { x = zoom_target.clamped_center.x, y = zoom_target.clamped_center.y }
                    log("检测到鼠标停止，初始锁定位置： " .. locked_center.x .. ", " .. locked_center.y)
                end
            end

            if should_stop_timer then
                is_timer_running = false
                obs.timer_remove(on_timer)
            end
        end
    end
end

function set_crop_settings(crop)
    if crop_filter ~= nil and crop_filter_settings ~= nil then
        obs.obs_data_set_int(crop_filter_settings, "left", math.floor(crop.x))
        obs.obs_data_set_int(crop_filter_settings, "top", math.floor(crop.y))
        obs.obs_data_set_int(crop_filter_settings, "cx", math.floor(crop.w))
        obs.obs_data_set_int(crop_filter_settings, "cy", math.floor(crop.h))
        obs.obs_source_update(crop_filter, crop_filter_settings)
    end
end

function on_transition_start(t)
    log("开始场景切换：移除当前裁剪避免渲染延迟")
    release_sceneitem()
end

function on_frontend_event(event)
    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        log("场景已切换")
        refresh_sceneitem(true)
    end
end

function on_update_transform()
    refresh_sceneitem(true)
    return true
end

function on_settings_modified(props, prop, settings)
    local name = obs.obs_property_name(prop)

    if name == "use_monitor_override" then
        local visible = obs.obs_data_get_bool(settings, "use_monitor_override")
        obs.obs_property_set_visible(obs.obs_properties_get(props, "monitor_override_x"), visible)
        obs.obs_property_set_visible(obs.obs_properties_get(props, "monitor_override_y"), visible)
        obs.obs_property_set_visible(obs.obs_properties_get(props, "monitor_override_w"), visible)
        obs.obs_property_set_visible(obs.obs_properties_get(props, "monitor_override_h"), visible)
        obs.obs_property_set_visible(obs.obs_properties_get(props, "monitor_override_sx"), visible)
        obs.obs_property_set_visible(obs.obs_properties_get(props, "monitor_override_sy"), visible)
        obs.obs_property_set_visible(obs.obs_properties_get(props, "monitor_override_dw"), visible)
        obs.obs_property_set_visible(obs.obs_properties_get(props, "monitor_override_dh"), visible)
        return true
    elseif name == "allow_all_sources" then
        local sources_list = obs.obs_properties_get(props, "source")
        populate_zoom_sources(sources_list)
        return true
    elseif name == "debug_logs" then
        if obs.obs_data_get_bool(settings, "debug_logs") then
            log_current_settings()
        end
    end

    return false
end

--- 将当前设置写入日志（用于问题排查）
function log_current_settings()
    local settings = {
        zoom_value = zoom_value,
        zoom_speed = zoom_speed,
        use_auto_follow_mouse = use_auto_follow_mouse,
        use_follow_outside_bounds = use_follow_outside_bounds,
        follow_speed = follow_speed,
        follow_border = follow_border,
        follow_safezone_sensitivity = follow_safezone_sensitivity,
        use_follow_auto_lock = use_follow_auto_lock,
        use_monitor_override = use_monitor_override,
        monitor_override_x = monitor_override_x,
        monitor_override_y = monitor_override_y,
        monitor_override_w = monitor_override_w,
        monitor_override_h = monitor_override_h,
        monitor_override_sx = monitor_override_sx,
        monitor_override_sy = monitor_override_sy,
        monitor_override_dw = monitor_override_dw,
        monitor_override_dh = monitor_override_dh,
        debug_logs = debug_logs
    }

    log("OBS 版本主号: " .. string.format("%d", major))
    log("当前设置：")
    log(format_table(settings))
end

function on_print_help()
    local help = "\n----------------------------------------------------\n" ..
        "OBS-Zoom-To-Mouse 帮助 v" .. VERSION .. "\n" ..
        "汉化: GPT 5\n" ..
        "----------------------------------------------------\n" ..
        "本脚本可将所选“显示采集”源缩放到鼠标位置。\n\n" ..
        "【缩放源】在当前场景中用于缩放的显示采集源\n" ..
        "【缩放倍数】缩放放大的倍数\n" ..
        "【缩放速度】缩放动画（放大/缩小）的速度\n" ..
        "【自动跟随鼠标】放大后是否自动跟踪鼠标\n" ..
        "【在边界外也跟随】当鼠标在源范围之外时是否也继续跟随\n" ..
        "【跟随速度】跟随鼠标时裁剪区域移动的速度\n" ..
        "【跟随边界】距离边缘的百分比，进入该区域重新启用跟随\n" ..
        "【锁定灵敏度】跟随接近目标中心到多近时触发“锁定”（停止跟随）\n" ..
        "【反向移动时自动锁定】鼠标移动方向反转时自动停止跟随（类似 RTS 镜头推拉）\n" ..
        "【允许任意缩放源】允许选择任意源为缩放源（非显示采集源需手动设置位置）\n" ..
        "【手动设置源位置】改为使用手动设置的 x/y/宽/高 与缩放系数（适用于克隆场景等缩放情形）\n" ..
        "【X/Y/宽度/高度】源左上角坐标与尺寸（像素）\n" ..
        "【缩放 X/Y】当源非 1:1 显示时用于校正鼠标坐标的缩放因子\n" ..
        "【显示器宽度/高度】显示器分辨率（像素），用于 macOS 鼠标 Y 翻转等\n" ..
        "【更多信息】打印此帮助到脚本日志\n" ..
        "【启用调试日志】在脚本日志中输出更多诊断信息\n\n"

    obs.script_log(obs.OBS_LOG_INFO, help)
end

function script_description()
    return "将所选“显示采集”源缩放以聚焦鼠标位置（中文汉化界面）"
end

function script_properties()
    local props = obs.obs_properties_create()

    -- 缩放源列表（OBS 内部名称 monitor_capture 即“显示采集”）
    local sources_list = obs.obs_properties_add_list(props, "source", "缩放源", obs.OBS_COMBO_TYPE_LIST,
        obs.OBS_COMBO_FORMAT_STRING)

    populate_zoom_sources(sources_list)

    local refresh_sources = obs.obs_properties_add_button(props, "refresh", "刷新缩放源",
        function()
            populate_zoom_sources(sources_list)
            monitor_info = get_monitor_info(source)
            return true
        end)
    obs.obs_property_set_long_description(refresh_sources,
        "点击以重新扫描并填充可用的“缩放源”下拉列表")

    -- 其他设置
    local zoom = obs.obs_properties_add_float(props, "zoom_value", "缩放倍数", 1, 5, 0.5)
    local zoom_speed = obs.obs_properties_add_float_slider(props, "zoom_speed", "缩放速度", 0.01, 1, 0.01)
    local follow = obs.obs_properties_add_bool(props, "follow", "自动跟随鼠标 ")
    obs.obs_property_set_long_description(follow,
        "启用后，放大完成将自动开始跟随，无需再按跟随热键")

    local follow_outside_bounds = obs.obs_properties_add_bool(props, "follow_outside_bounds", "在边界外也跟随 ")
    obs.obs_property_set_long_description(follow_outside_bounds,
        "启用后，当鼠标超出缩放源范围时也会继续跟随")

    local follow_speed = obs.obs_properties_add_float_slider(props, "follow_speed", "跟随速度", 0.01, 1, 0.01)
    local follow_border = obs.obs_properties_add_int_slider(props, "follow_border", "跟随边界 (%)", 0, 50, 1)
    local safezone_sense = obs.obs_properties_add_int_slider(props,
        "follow_safezone_sensitivity", "锁定灵敏度", 1, 20, 1)
    local follow_auto_lock = obs.obs_properties_add_bool(props, "follow_auto_lock", "反向移动时自动锁定 ")
    obs.obs_property_set_long_description(follow_auto_lock,
        "启用后，鼠标朝边缘移动会触发跟随，但若马上反向朝中心移动，则停止跟随，类似 RTS 镜头行为")

    local allow_all = obs.obs_properties_add_bool(props, "allow_all_sources", "允许任意缩放源 ")
    obs.obs_property_set_long_description(allow_all, "启用后可选任意源作为缩放源。\n" ..
        "注意：若不是“显示采集”源，必须启用“手动设置源位置”并正确填写。")

    local override = obs.obs_properties_add_bool(props, "use_monitor_override", "手动设置源位置 ")
    obs.obs_property_set_long_description(override,
        "启用后，将使用下列手动设置的大小/位置/缩放参数，而非自动计算值")

    local override_x = obs.obs_properties_add_int(props, "monitor_override_x", "X", -10000, 10000, 1)
    local override_y = obs.obs_properties_add_int(props, "monitor_override_y", "Y", -10000, 10000, 1)
    local override_w = obs.obs_properties_add_int(props, "monitor_override_w", "宽度", 0, 10000, 1)
    local override_h = obs.obs_properties_add_int(props, "monitor_override_h", "高度", 0, 10000, 1)
    local override_sx = obs.obs_properties_add_float(props, "monitor_override_sx", "缩放 X ", 0, 100, 0.01)
    local override_sy = obs.obs_properties_add_float(props, "monitor_override_sy", "缩放 Y ", 0, 100, 0.01)
    local override_dw = obs.obs_properties_add_int(props, "monitor_override_dw", "显示器宽度 ", 0, 10000, 1)
    local override_dh = obs.obs_properties_add_int(props, "monitor_override_dh", "显示器高度 ", 0, 10000, 1)

    obs.obs_property_set_long_description(override_sx, "通常为 1；若源被缩放（如克隆场景）则按比例设置")
    obs.obs_property_set_long_description(override_sy, "通常为 1；若源被缩放（如克隆场景）则按比例设置")
    obs.obs_property_set_long_description(override_dw, "显示器的 X 分辨率")
    obs.obs_property_set_long_description(override_dh, "显示器的 Y 分辨率")

    local help = obs.obs_properties_add_button(props, "help_button", "更多信息", on_print_help)
    obs.obs_property_set_long_description(help,
        "点击将帮助说明打印到“脚本日志”")

    local debug = obs.obs_properties_add_bool(props, "debug_logs", "启用调试日志 ")
    obs.obs_property_set_long_description(debug,
        "启用后，脚本会在日志中输出诊断信息（用于调试/提交 issue）")

    obs.obs_property_set_visible(override_x, use_monitor_override)
    obs.obs_property_set_visible(override_y, use_monitor_override)
    obs.obs_property_set_visible(override_w, use_monitor_override)
    obs.obs_property_set_visible(override_h, use_monitor_override)
    obs.obs_property_set_visible(override_sx, use_monitor_override)
    obs.obs_property_set_visible(override_sy, use_monitor_override)
    obs.obs_property_set_visible(override_dw, use_monitor_override)
    obs.obs_property_set_visible(override_dh, use_monitor_override)
    obs.obs_property_set_modified_callback(override, on_settings_modified)
    obs.obs_property_set_modified_callback(allow_all, on_settings_modified)
    obs.obs_property_set_modified_callback(debug, on_settings_modified)

    return props
end

function script_load(settings)
    sceneitem_transform_orig = nil

    -- 注册热键
    hotkey_zoom_id = obs.obs_hotkey_register_frontend("toggle_zoom_hotkey", "切换缩放到鼠标",
        on_toggle_zoom)

    hotkey_follow_id = obs.obs_hotkey_register_frontend("toggle_follow_hotkey", "切换缩放时跟随鼠标",
        on_toggle_follow)

    -- 载入热键绑定
    local hotkey_save_array = obs.obs_data_get_array(settings, "obs_zoom_to_mouse.hotkey.zoom")
    obs.obs_hotkey_load(hotkey_zoom_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    hotkey_save_array = obs.obs_data_get_array(settings, "obs_zoom_to_mouse.hotkey.follow")
    obs.obs_hotkey_load(hotkey_follow_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)

    -- 载入其他设置
    zoom_value = obs.obs_data_get_double(settings, "zoom_value")
    zoom_speed = obs.obs_data_get_double(settings, "zoom_speed")
    use_auto_follow_mouse = obs.obs_data_get_bool(settings, "follow")
    use_follow_outside_bounds = obs.obs_data_get_bool(settings, "follow_outside_bounds")
    follow_speed = obs.obs_data_get_double(settings, "follow_speed")
    follow_border = obs.obs_data_get_int(settings, "follow_border")
    follow_safezone_sensitivity = obs.obs_data_get_int(settings, "follow_safezone_sensitivity")
    use_follow_auto_lock = obs.obs_data_get_bool(settings, "follow_auto_lock")
    allow_all_sources = obs.obs_data_get_bool(settings, "allow_all_sources")
    use_monitor_override = obs.obs_data_get_bool(settings, "use_monitor_override")
    monitor_override_x = obs.obs_data_get_int(settings, "monitor_override_x")
    monitor_override_y = obs.obs_data_get_int(settings, "monitor_override_y")
    monitor_override_w = obs.obs_data_get_int(settings, "monitor_override_w")
    monitor_override_h = obs.obs_data_get_int(settings, "monitor_override_h")
    monitor_override_sx = obs.obs_data_get_double(settings, "monitor_override_sx")
    monitor_override_sy = obs.obs_data_get_double(settings, "monitor_override_sy")
    monitor_override_dw = obs.obs_data_get_int(settings, "monitor_override_dw")
    monitor_override_dh = obs.obs_data_get_int(settings, "monitor_override_dh")
    debug_logs = obs.obs_data_get_bool(settings, "debug_logs")

    obs.obs_frontend_add_event_callback(on_frontend_event)

    if debug_logs then
        log_current_settings()
    end

    -- 为每个过渡源单独绑定 transition_start（全局 source_transition_start 不会触发）
    local transitions = obs.obs_frontend_get_transitions()
    if transitions ~= nil then
        for i, s in pairs(transitions) do
            local name = obs.obs_source_get_name(s)
            log("为转场添加 transition_start 监听: " .. name)
            local handler = obs.obs_source_get_signal_handler(s)
            obs.signal_handler_connect(handler, "transition_start", on_transition_start)
        end
        obs.source_list_release(transitions)
    end

    if ffi.os == "Linux" and not x11_display then
        log("错误：无法获取 Linux 的 X11 Display。\n" ..
            "鼠标位置将不正确。")
    end
end

function script_unload()
    if major > 29 then
        local transitions = obs.obs_frontend_get_transitions()
        if transitions ~= nil then
            for i, s in pairs(transitions) do
                local handler = obs.obs_source_get_signal_handler(s)
                obs.signal_handler_disconnect(handler, "transition_start", on_transition_start)
            end
            obs.source_list_release(transitions)
        end

        obs.obs_hotkey_unregister(on_toggle_zoom)
        obs.obs_hotkey_unregister(on_toggle_follow)
        obs.obs_frontend_remove_event_callback(on_frontend_event)
        release_sceneitem()
    end

    if x11_lib ~= nil and x11_display ~= nil then
        x11_lib.XCloseDisplay(x11_display)
    end
end

function script_defaults(settings)
    obs.obs_data_set_default_double(settings, "zoom_value", 2)
    obs.obs_data_set_default_double(settings, "zoom_speed", 0.06)
    obs.obs_data_set_default_bool(settings, "follow", true)
    obs.obs_data_set_default_bool(settings, "follow_outside_bounds", false)
    obs.obs_data_set_default_double(settings, "follow_speed", 0.25)
    obs.obs_data_set_default_int(settings, "follow_border", 8)
    obs.obs_data_set_default_int(settings, "follow_safezone_sensitivity", 4)
    obs.obs_data_set_default_bool(settings, "follow_auto_lock", false)
    obs.obs_data_set_default_bool(settings, "allow_all_sources", false)
    obs.obs_data_set_default_bool(settings, "use_monitor_override", false)
    obs.obs_data_set_default_int(settings, "monitor_override_x", 0)
    obs.obs_data_set_default_int(settings, "monitor_override_y", 0)
    obs.obs_data_set_default_int(settings, "monitor_override_w", 1920)
    obs.obs_data_set_default_int(settings, "monitor_override_h", 1080)
    obs.obs_data_set_default_double(settings, "monitor_override_sx", 1)
    obs.obs_data_set_default_double(settings, "monitor_override_sy", 1)
    obs.obs_data_set_default_int(settings, "monitor_override_dw", 1920)
    obs.obs_data_set_default_int(settings, "monitor_override_dh", 1080)
    obs.obs_data_set_default_bool(settings, "debug_logs", false)
end

function script_save(settings)
    if hotkey_zoom_id ~= nil then
        local hotkey_save_array = obs.obs_hotkey_save(hotkey_zoom_id)
        obs.obs_data_set_array(settings, "obs_zoom_to_mouse.hotkey.zoom", hotkey_save_array)
        obs.obs_data_array_release(hotkey_save_array)
    end

    if hotkey_follow_id ~= nil then
        local hotkey_save_array = obs.obs_hotkey_save(hotkey_follow_id)
        obs.obs_data_set_array(settings, "obs_zoom_to_mouse.hotkey.follow", hotkey_save_array)
        obs.obs_data_array_release(hotkey_save_array)
    end
end

function script_update(settings)
    local old_source_name = source_name
    local old_override = use_monitor_override
    local old_x = monitor_override_x
    local old_y = monitor_override_y
    local old_w = monitor_override_w
    local old_h = monitor_override_h
    local old_sx = monitor_override_sx
    local old_sy = monitor_override_sy
    local old_dw = monitor_override_dw
    local old_dh = monitor_override_dh

    source_name = obs.obs_data_get_string(settings, "source")
    zoom_value = obs.obs_data_get_double(settings, "zoom_value")
    zoom_speed = obs.obs_data_get_double(settings, "zoom_speed")
    use_auto_follow_mouse = obs.obs_data_get_bool(settings, "follow")
    use_follow_outside_bounds = obs.obs_data_get_bool(settings, "follow_outside_bounds")
    follow_speed = obs.obs_data_get_double(settings, "follow_speed")
    follow_border = obs.obs_data_get_int(settings, "follow_border")
    follow_safezone_sensitivity = obs.obs_data_get_int(settings, "follow_safezone_sensitivity")
    use_follow_auto_lock = obs.obs_data_get_bool(settings, "follow_auto_lock")
    allow_all_sources = obs.obs_data_get_bool(settings, "allow_all_sources")
    use_monitor_override = obs.obs_data_get_bool(settings, "use_monitor_override")
    monitor_override_x = obs.obs_data_get_int(settings, "monitor_override_x")
    monitor_override_y = obs.obs_data_get_int(settings, "monitor_override_y")
    monitor_override_w = obs.obs_data_get_int(settings, "monitor_override_w")
    monitor_override_h = obs.obs_data_get_int(settings, "monitor_override_h")
    monitor_override_sx = obs.obs_data_get_double(settings, "monitor_override_sx")
    monitor_override_sy = obs.obs_data_get_double(settings, "monitor_override_sy")
    monitor_override_dw = obs.obs_data_get_int(settings, "monitor_override_dw")
    monitor_override_dh = obs.obs_data_get_int(settings, "monitor_override_dh")
    debug_logs = obs.obs_data_get_bool(settings, "debug_logs")

    if source_name ~= old_source_name then
        refresh_sceneitem(true)
    end

    if source_name ~= old_source_name or
        use_monitor_override ~= old_override or
        monitor_override_x ~= old_x or
        monitor_override_y ~= old_y or
        monitor_override_w ~= old_w or
        monitor_override_h ~= old_h or
        monitor_override_sx ~= old_sx or
        monitor_override_sy ~= old_sy or
        monitor_override_w ~= old_dw or
        monitor_override_h ~= old_dh then
        monitor_info = get_monitor_info(source)
    end
end

function populate_zoom_sources(list)
    obs.obs_property_list_clear(list)

    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        local dc_info = get_dc_info()
        obs.obs_property_list_add_string(list, "<None>", "obs-zoom-to-mouse-none")
        for _, source in ipairs(sources) do
            local source_type = obs.obs_source_get_id(source)
            if source_type == dc_info.source_id or allow_all_sources then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(list, name, name)
            end
        end

        obs.source_list_release(sources)
    end
end
