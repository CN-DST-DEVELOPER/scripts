local PostProcessor__index = getmetatable(PostProcessor).__index

if TheNet:IsDedicated() then
    function PostProcessor__index:SetColourCubeData(index, src, dest) end
    function PostProcessor__index:SetColourCubeLerp(index, lerp) end
    function PostProcessor__index:SetOverlayTex(tex) end
    function PostProcessor__index:SetColourModifier(mod) end
    function PostProcessor__index:SetOverlayBlend(blend) end
    function PostProcessor__index:SetLineDistortLineParams(p1x, p1y, p2x, p2y) end
    function PostProcessor__index:SetLineDistortDistortionParams(width, displacement) end
    function PostProcessor__index:SetDistortionEffectTime(time) end
    function PostProcessor__index:SetDistortionFactor(factor) end
    function PostProcessor__index:SetDistortionRadii(inner, outer) end
    function PostProcessor__index:SetDistortionFishEyeIntensity(intensity) end
    function PostProcessor__index:SetDistortionFishEyeTime(time) end
    function PostProcessor__index:SetBloomEnabled(enabled) end
    function PostProcessor__index:IsBloomEnabled() return true end
    function PostProcessor__index:SetDistortionEnabled(enabled) end
    function PostProcessor__index:IsDistortionEnabled() return true end
    function PostProcessor__index:SetLunacyEnabled(enabled) end
    function PostProcessor__index:SetLunacyIntensity(intensity) end
    function PostProcessor__index:SetZoomBlurEnabled(enabled) end
	function PostProcessor__index:SetRingDistortPoints(p1x, p1y, p2x, p2y) end
    function PostProcessor__index:SetRingDistortRadii(inner_radius, outer_radius, ring_width_inner, ring_width_outer) end
    function PostProcessor__index:SetRingDistortShapeParams(spacing_power, inner_fade_amount, displacement_strength, aspect_ratio) end
    function PostProcessor__index:SetRingDistortRingCount(ring_count) end
    function PostProcessor__index:SetRingDistortPhase(phase) end
    return
end

function PostProcessor__index:SetColourCubeData(index, src, dest)
    if index == 0 then
        self:SetTextureSampler(TexSamplers.CC0_SOURCE, src)
        self:SetTextureSampler(TexSamplers.CC0_DEST, dest)
    elseif index == 1 then
        self:SetTextureSampler(TexSamplers.CC1_SOURCE, src)
        self:SetTextureSampler(TexSamplers.CC1_DEST, dest)
    elseif index == 2 then
        self:SetTextureSampler(TexSamplers.CC2_SOURCE, src)
        self:SetTextureSampler(TexSamplers.CC2_DEST, dest)
    end
end

function PostProcessor__index:SetColourCubeLerp(index, lerp)
    if index == 0 then
        self:SetUniformVariable(UniformVariables.CC_LERP_PARAMS, lerp, lerp, lerp)
    elseif index == 1 then
        self:SetUniformVariable(UniformVariables.CC_LAYER_PARAMS, lerp)
    elseif index == 2 then
        self:SetUniformVariable(UniformVariables.CC_LAYER_PARAMS, nil, lerp)
    end
end

function PostProcessor__index:SetOverlayTex(tex)
    self:SetTextureSampler(TexSamplers.LUNACY_OVERLAY_IMAGE, tex)
end

function PostProcessor__index:SetColourModifier(mod)
    self:SetUniformVariable(UniformVariables.INTENSITY_MODIFIER, mod)
end

function PostProcessor__index:SetOverlayBlend(blend)
    self:SetUniformVariable(UniformVariables.OVERLAY_BLEND, blend)
end

function PostProcessor__index:SetLineDistortLineParams(p1x, p1y, p2x, p2y, aspect_ratio)
    self:SetUniformVariable(UniformVariables.LINEDISTORT_LINE_CORRECTED_PARAMS, p1x * aspect_ratio, p1y, p2x * aspect_ratio, p2y)

    local dx, dy = p2x - p1x, p2y - p1y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        dx, dy = dx / len, dy / len
    end
    self:SetUniformVariable(UniformVariables.LINEDISTORT_LINE_DIR_PARAMS, dx, dy, aspect_ratio)
end

function PostProcessor__index:SetLineDistortDistortionParams(width, displacement)
    self:SetUniformVariable(UniformVariables.LINEDISTORT_DISTORTION_PARAMS, width, displacement)
end

function PostProcessor__index:SetRingDistortPoints(p1x, p1y, p2x, p2y)
    self:SetUniformVariable(UniformVariables.RINGDISTORT_POINTS, p1x, p1y, p2x, p2y)
end

function PostProcessor__index:SetRingDistortRadii(inner_radius, outer_radius, ring_width_inner, ring_width_outer)
    self:SetUniformVariable(UniformVariables.RINGDISTORT_RADII, inner_radius, outer_radius, ring_width_inner, ring_width_outer)
end

function PostProcessor__index:SetRingDistortShapeParams(spacing_power, inner_fade_amount, displacement_strength, aspect_ratio)
    self:SetUniformVariable(UniformVariables.RINGDISTORT_SHAPE_PARAMS, spacing_power, inner_fade_amount, displacement_strength, aspect_ratio)
end

function PostProcessor__index:SetRingDistortRingCount(ring_count)
    self:SetUniformVariable(UniformVariables.RINGDISTORT_RING_PARAMS, ring_count)
end

function PostProcessor__index:SetRingDistortPhase(phase)
    self:SetUniformVariable(UniformVariables.RINGDISTORT_RING_PARAMS, nil, phase)
end

function PostProcessor__index:SetDistortionEffectTime(time)
    self:SetUniformVariable(UniformVariables.DISTORTION_PARAMS, time)
end

function PostProcessor__index:SetDistortionFactor(factor)
    self:SetUniformVariable(UniformVariables.DISTORTION_PARAMS, nil, factor)
end

function PostProcessor__index:SetDistortionRadii(inner, outer)
    self:SetUniformVariable(UniformVariables.DISTORTION_PARAMS, nil, nil, inner, outer)
end

function PostProcessor__index:SetDistortionFishEyeIntensity(intensity)
    self:SetUniformVariable(UniformVariables.DISTORTION_FISHEYE_PARAMS, intensity)
end

function PostProcessor__index:SetDistortionFishEyeTime(time)
    self:SetUniformVariable(UniformVariables.DISTORTION_FISHEYE_PARAMS, nil, time)
end

local distortion_enabled = false
local lunacy_enabled = false
local fishlens_active = false

function PostProcessor__index:SetDistortionFishLensRadius(r)
	self:SetUniformVariable(UniformVariables.DISTORTION_FISHLENS_PARAMS, r)

	fishlens_active = r > 0
	self:EnablePostProcessEffect(PostProcessorEffects.Distort, distortion_enabled or fishlens_active)
end

function PostProcessor__index:SetDistortionFishLensAspectRatio(aspect_ratio)
	self:SetUniformVariable(UniformVariables.DISTORTION_FISHLENS_PARAMS, nil, aspect_ratio)
end

local bloom_enabled = false

function PostProcessor__index:SetBloomEnabled(enabled)
    bloom_enabled = enabled
    self:EnablePostProcessEffect(PostProcessorEffects.Bloom, bloom_enabled)
end

function PostProcessor__index:IsBloomEnabled()
    return bloom_enabled
end

function PostProcessor__index:SetDistortionEnabled(enabled)
    distortion_enabled = enabled
	self:EnablePostProcessEffect(PostProcessorEffects.Distort, distortion_enabled or fishlens_active)

    self:SetZoomBlurEnabled(distortion_enabled and lunacy_enabled)
end

function PostProcessor__index:IsDistortionEnabled()
    return distortion_enabled
end

function PostProcessor__index:SetLunacyEnabled(enabled)
    lunacy_enabled = enabled
    self:EnablePostProcessEffect(PostProcessorEffects.Lunacy, lunacy_enabled)

    self:SetZoomBlurEnabled(distortion_enabled and lunacy_enabled)
end

function PostProcessor__index:SetLunacyIntensity(intensity)
    self:SetUniformVariable(UniformVariables.LUNACY_INTENSITY, intensity)
end

--Zoom Blur is only enabled when distortion and lunacy is on!
function PostProcessor__index:SetZoomBlurEnabled(enabled)
    self:EnablePostProcessEffect(PostProcessorEffects.ZoomBlur, enabled)
end

function PostProcessor__index:SetMoonPulseParams(p1, p2, p3, p4)
    self:SetUniformVariable(UniformVariables.MOONPULSE_PARAMS, p1, p2, p3, p4)
end

function PostProcessor__index:SetMoonPulseGradingParams(p1, p2, p3, p4)
    self:SetUniformVariable(UniformVariables.MOONPULSE_GRADING_PARAMS, p1, p2, p3, p4)
end

--only used for sampler effects, give samplers access to this vec4 uniform containing {buffer_width, buffer_height, 1 / buffer_width, 1 / buffer_height}
UniformVariables.SAMPLER_PARAMS = hash("SAMPLER_PARAMS")

function BuildColourCubeShader()
    local IDENTITY_COLOURCUBE = "images/colour_cubes/identity_colourcube.tex"
    TexSamplers.CC0_SOURCE = PostProcessor:AddTextureSampler(IDENTITY_COLOURCUBE)
    PostProcessor:SetTextureSamplerState(TexSamplers.CC0_SOURCE, WRAP_MODE.CLAMP_TO_EDGE)
    PostProcessor:SetTextureSamplerFilter(TexSamplers.CC0_SOURCE, FILTER_MODE.POINT, FILTER_MODE.POINT, MIP_FILTER_MODE.NONE)
    TexSamplers.CC0_DEST = PostProcessor:AddTextureSampler(IDENTITY_COLOURCUBE)
    PostProcessor:SetTextureSamplerState(TexSamplers.CC0_DEST, WRAP_MODE.CLAMP_TO_EDGE)
    PostProcessor:SetTextureSamplerFilter(TexSamplers.CC0_DEST, FILTER_MODE.POINT, FILTER_MODE.POINT, MIP_FILTER_MODE.NONE)

    TexSamplers.CC1_SOURCE = PostProcessor:AddTextureSampler(IDENTITY_COLOURCUBE)
    PostProcessor:SetTextureSamplerState(TexSamplers.CC1_SOURCE, WRAP_MODE.CLAMP_TO_EDGE)
    PostProcessor:SetTextureSamplerFilter(TexSamplers.CC1_SOURCE, FILTER_MODE.POINT, FILTER_MODE.POINT, MIP_FILTER_MODE.NONE)
    TexSamplers.CC1_DEST = PostProcessor:AddTextureSampler(IDENTITY_COLOURCUBE)
    PostProcessor:SetTextureSamplerState(TexSamplers.CC1_DEST, WRAP_MODE.CLAMP_TO_EDGE)
    PostProcessor:SetTextureSamplerFilter(TexSamplers.CC1_DEST, FILTER_MODE.POINT, FILTER_MODE.POINT, MIP_FILTER_MODE.NONE)

    TexSamplers.CC2_SOURCE = PostProcessor:AddTextureSampler(IDENTITY_COLOURCUBE)
    PostProcessor:SetTextureSamplerState(TexSamplers.CC2_SOURCE, WRAP_MODE.CLAMP_TO_EDGE)
    PostProcessor:SetTextureSamplerFilter(TexSamplers.CC2_SOURCE, FILTER_MODE.POINT, FILTER_MODE.POINT, MIP_FILTER_MODE.NONE)
    TexSamplers.CC2_DEST = PostProcessor:AddTextureSampler(IDENTITY_COLOURCUBE)
    PostProcessor:SetTextureSamplerState(TexSamplers.CC2_DEST, WRAP_MODE.CLAMP_TO_EDGE)
    PostProcessor:SetTextureSamplerFilter(TexSamplers.CC2_DEST, FILTER_MODE.POINT, FILTER_MODE.POINT, MIP_FILTER_MODE.NONE)

    UniformVariables.CC_LERP_PARAMS = PostProcessor:AddUniformVariable("CC_LERP_PARAMS", 3)
    UniformVariables.CC_LAYER_PARAMS = PostProcessor:AddUniformVariable("CC_LAYER_PARAMS", 2)
    UniformVariables.INTENSITY_MODIFIER = PostProcessor:AddUniformVariable("INTENSITY_MODIFIER", 1)
    UniformVariables.LINEDISTORT_LINE_CORRECTED_PARAMS = PostProcessor:AddUniformVariable("LINEDISTORT_LINE_CORRECTED_PARAMS", 4)
    UniformVariables.LINEDISTORT_LINE_DIR_PARAMS = PostProcessor:AddUniformVariable("LINEDISTORT_LINE_DIR_PARAMS", 3)
    UniformVariables.LINEDISTORT_DISTORTION_PARAMS = PostProcessor:AddUniformVariable("LINEDISTORT_DISTORTION_PARAMS", 2)

    UniformVariables.RINGDISTORT_POINTS = PostProcessor:AddUniformVariable("RINGDISTORT_POINTS", 4)
    UniformVariables.RINGDISTORT_RADII = PostProcessor:AddUniformVariable("RINGDISTORT_RADII", 4)
    UniformVariables.RINGDISTORT_SHAPE_PARAMS = PostProcessor:AddUniformVariable("RINGDISTORT_SHAPE_PARAMS", 4)
    UniformVariables.RINGDISTORT_RING_PARAMS = PostProcessor:AddUniformVariable("RINGDISTORT_RING_PARAMS", 2)

    PostProcessor:SetColourModifier(1)

    SamplerEffects.CombineColourCubes = PostProcessor:AddSamplerEffect("shaders/combine_colour_cubes.ksh", SamplerSizes.Static, 1024, 32, SamplerColourMode.RGB, SamplerEffectBase.Texture, TexSamplers.CC0_SOURCE)
    PostProcessor:AddSampler(SamplerEffects.CombineColourCubes, SamplerEffectBase.Texture, TexSamplers.CC0_DEST)
    PostProcessor:AddSampler(SamplerEffects.CombineColourCubes, SamplerEffectBase.Texture, TexSamplers.CC1_SOURCE)
    PostProcessor:AddSampler(SamplerEffects.CombineColourCubes, SamplerEffectBase.Texture, TexSamplers.CC1_DEST)
    PostProcessor:AddSampler(SamplerEffects.CombineColourCubes, SamplerEffectBase.Texture, TexSamplers.CC2_SOURCE)
    PostProcessor:AddSampler(SamplerEffects.CombineColourCubes, SamplerEffectBase.Texture, TexSamplers.CC2_DEST)
    PostProcessor:SetEffectUniformVariables(SamplerEffects.CombineColourCubes, UniformVariables.CC_LERP_PARAMS, UniformVariables.CC_LAYER_PARAMS, UniformVariables.INTENSITY_MODIFIER)
    PostProcessor:SetSamplerEffectState(SamplerEffects.CombineColourCubes, WRAP_MODE.CLAMP_TO_EDGE)
    PostProcessor:SetSamplerEffectFilter(SamplerEffects.CombineColourCubes, FILTER_MODE.LINEAR, FILTER_MODE.POINT, MIP_FILTER_MODE.NONE)
    PostProcessor:SetColourCubeSamplerEffect(SamplerEffects.CombineColourCubes)

    PostProcessorEffects.ColourCube = PostProcessor:AddPostProcessEffect("shaders/postprocess_colourcube.ksh")
    PostProcessor:AddSampler(PostProcessorEffects.ColourCube, SamplerEffectBase.Shader, SamplerEffects.CombineColourCubes)
    PostProcessor:SetEffectUniformVariables(PostProcessorEffects.ColourCube,
        UniformVariables.LINEDISTORT_LINE_CORRECTED_PARAMS, UniformVariables.LINEDISTORT_LINE_DIR_PARAMS, UniformVariables.LINEDISTORT_DISTORTION_PARAMS,
        UniformVariables.RINGDISTORT_POINTS, UniformVariables.RINGDISTORT_RADII, UniformVariables.RINGDISTORT_SHAPE_PARAMS,
        UniformVariables.RINGDISTORT_RING_PARAMS)

    PostProcessorEffects.ColourCubeLineDistort = PostProcessor:AddPostProcessEffect("shaders/postprocess_colourcube_linedistort.ksh")
    PostProcessor:AddSampler(PostProcessorEffects.ColourCubeLineDistort, SamplerEffectBase.Shader, SamplerEffects.CombineColourCubes)
    PostProcessor:SetEffectUniformVariables(PostProcessorEffects.ColourCubeLineDistort,
        UniformVariables.LINEDISTORT_LINE_CORRECTED_PARAMS, UniformVariables.LINEDISTORT_LINE_DIR_PARAMS, UniformVariables.LINEDISTORT_DISTORTION_PARAMS,
        UniformVariables.RINGDISTORT_POINTS, UniformVariables.RINGDISTORT_RADII, UniformVariables.RINGDISTORT_SHAPE_PARAMS,
        UniformVariables.RINGDISTORT_RING_PARAMS)

--[[
    PostProcessorEffects.ColourCubeRingDistort = PostProcessor:AddPostProcessEffect("shaders/postprocess_colourcube_ringdistort.ksh")
    PostProcessor:AddSampler(PostProcessorEffects.ColourCubeRingDistort, SamplerEffectBase.Shader, SamplerEffects.CombineColourCubes)
    PostProcessor:SetEffectUniformVariables(PostProcessorEffects.ColourCubeRingDistort,
        UniformVariables.LINEDISTORT_LINE_CORRECTED_PARAMS, UniformVariables.LINEDISTORT_LINE_DIR_PARAMS, UniformVariables.LINEDISTORT_DISTORTION_PARAMS,
        UniformVariables.RINGDISTORT_POINTS, UniformVariables.RINGDISTORT_RADII, UniformVariables.RINGDISTORT_SHAPE_PARAMS,
        UniformVariables.RINGDISTORT_RING_PARAMS)
]]
end

function BuildZoomBlurShader()
    --[[
    local tap_count = 8
    local strength = 0.015
    local ONE_OVER_TAP_COUNT = 1 / tap_count

    local zoom_blur_params = {}

    local total_weight = 0

    for i = 1, tap_count do
        local percent = i * ONE_OVER_TAP_COUNT;
        local weight = 4*(percent - percent * percent);
        zoom_blur_params[i] = percent * strength;
        zoom_blur_params[i + tap_count] = weight;
        total_weight = total_weight + weight;
    end

    for i = 1, tap_count do
        zoom_blur_params[i + tap_count] = zoom_blur_params[i + tap_count] / total_weight;
    end

    for i = 1, 16, 4 do
        print(string.format("const vec4 ZOOM_BLUR_PARAMS%i = vec4(%.8f, %.8f, %.8f, %.8f);", (i-1)/4, zoom_blur_params[i], zoom_blur_params[i + 1], zoom_blur_params[i + 2], zoom_blur_params[i + 3]))
    end
    --]]
    UniformVariables.OVERLAY_BLEND = PostProcessor:AddUniformVariable("OVERLAY_BLEND", 1)

    PostProcessorEffects.ZoomBlur = PostProcessor:AddPostProcessEffect("shaders/postprocess_zoomblur.ksh")
    PostProcessor:SetEffectUniformVariables(PostProcessorEffects.ZoomBlur, UniformVariables.OVERLAY_BLEND)
end

function BuildBloomShader()
    PostProcessor:SetBloomSamplerParams(SamplerSizes.Relative, 0.25, 0.25, SamplerColourMode.RGB)
    SamplerEffects.BlurH = PostProcessor:AddSamplerEffect("shaders/blurh.ksh", SamplerSizes.Relative, 0.25, 0.25, SamplerColourMode.RGB, SamplerEffectBase.BloomSampler)
    PostProcessor:SetEffectUniformVariables(SamplerEffects.BlurH, UniformVariables.SAMPLER_PARAMS)

    SamplerEffects.BlurV = PostProcessor:AddSamplerEffect("shaders/blurv.ksh", SamplerSizes.Relative, 0.25, 0.25, SamplerColourMode.RGB, SamplerEffectBase.Shader, SamplerEffects.BlurH)
    PostProcessor:SetEffectUniformVariables(SamplerEffects.BlurV, UniformVariables.SAMPLER_PARAMS)

    PostProcessor:SetSamplerEffectFilter(SamplerEffects.BlurV, FILTER_MODE.LINEAR, FILTER_MODE.LINEAR, MIP_FILTER_MODE.NONE)

    PostProcessorEffects.Bloom = PostProcessor:AddPostProcessEffect("shaders/postprocess_bloom.ksh")
    PostProcessor:AddSampler(PostProcessorEffects.Bloom, SamplerEffectBase.Shader, SamplerEffects.BlurV)
end

function BuildDistortShader()
    UniformVariables.DISTORTION_PARAMS = PostProcessor:AddUniformVariable("DISTORTION_PARAMS", 4)
    UniformVariables.DISTORTION_FISHEYE_PARAMS = PostProcessor:AddUniformVariable("FISHEYE_PARAMS", 2)
	UniformVariables.DISTORTION_FISHLENS_PARAMS = PostProcessor:AddUniformVariable("FISHLENS_PARAMS", 2)

    PostProcessorEffects.Distort = PostProcessor:AddPostProcessEffect("shaders/postprocess_distort.ksh")
	PostProcessor:SetEffectUniformVariables(PostProcessorEffects.Distort, UniformVariables.DISTORTION_PARAMS, UniformVariables.DISTORTION_FISHEYE_PARAMS, UniformVariables.DISTORTION_FISHLENS_PARAMS)
end

function BuildLunacyShader()
    UniformVariables.LUNACY_INTENSITY = PostProcessor:AddUniformVariable("LUNACY_INTENSITY", 4)

    TexSamplers.LUNACY_OVERLAY_IMAGE = PostProcessor:AddTextureSampler("images/overlays_lunacy.tex")
    PostProcessor:SetTextureSamplerFilter(TexSamplers.LUNACY_OVERLAY_IMAGE, FILTER_MODE.LINEAR, FILTER_MODE.LINEAR, MIP_FILTER_MODE.LINEAR)

    PostProcessorEffects.Lunacy = PostProcessor:AddPostProcessEffect("shaders/postprocess_lunacy.ksh")
    PostProcessor:AddSampler(PostProcessorEffects.Lunacy, SamplerEffectBase.Texture, TexSamplers.LUNACY_OVERLAY_IMAGE)
    PostProcessor:AddSampler(PostProcessorEffects.Lunacy, SamplerEffectBase.Smoke)
    PostProcessor:SetEffectUniformVariables(PostProcessorEffects.Lunacy, UniformVariables.OVERLAY_BLEND, UniformVariables.LUNACY_INTENSITY)
end

function BuildMoonPulseShader()
    UniformVariables.MOONPULSE_PARAMS = PostProcessor:AddUniformVariable("MOONPULSE_PARAMS", 4)

    PostProcessorEffects.MoonPulse = PostProcessor:AddPostProcessEffect("shaders/postprocess_moonpulse.ksh")
    PostProcessor:SetEffectUniformVariables(PostProcessorEffects.MoonPulse, UniformVariables.MOONPULSE_PARAMS)
end

function BuildMoonPulseGradingShader()
    UniformVariables.MOONPULSE_GRADING_PARAMS = PostProcessor:AddUniformVariable("MOONPULSE_GRADING_PARAMS", 4)

    PostProcessorEffects.MoonPulseGrading = PostProcessor:AddPostProcessEffect("shaders/postprocess_moonpulsegrading.ksh")
    PostProcessor:SetEffectUniformVariables(PostProcessorEffects.MoonPulseGrading, UniformVariables.MOONPULSE_GRADING_PARAMS)
end

function BuildModShaders()
    local postinitfns = ModManager:GetPostInitFns("ModShadersInit")

    for i, fn in ipairs(postinitfns) do
        fn()
    end
end

function SortAndEnableShaders()
    PostProcessor:SetBasePostProcessEffect(PostProcessorEffects.ColourCube)
    --bool PostProcessor:SetPostProcessEffectBefore(source_effect_id, target_effect_id) returns true if successfully added into the sorted post processor list.
    --bool PostProcessor:SetPostProcessEffectAfter(source_effect_id, target_effect_id) returns true if successfully added into the sorted post processor list.
--    PostProcessor:SetPostProcessEffectBefore(PostProcessorEffects.ColourCubeRingDistort , PostProcessorEffects.ColourCube)
--    PostProcessor:SetPostProcessEffectBefore(PostProcessorEffects.ColourCubeLineDistort, PostProcessorEffects.ColourCubeRingDistort)
    PostProcessor:SetPostProcessEffectBefore(PostProcessorEffects.ColourCubeLineDistort, PostProcessorEffects.ColourCube)

	PostProcessor:SetPostProcessEffectBefore(PostProcessorEffects.Distort, PostProcessorEffects.ColourCubeLineDistort)
    PostProcessor:SetPostProcessEffectBefore(PostProcessorEffects.Bloom, PostProcessorEffects.Distort)
    PostProcessor:SetPostProcessEffectBefore(PostProcessorEffects.ZoomBlur, PostProcessorEffects.Bloom)
    PostProcessor:SetPostProcessEffectAfter(PostProcessorEffects.Lunacy, PostProcessorEffects.ColourCube)
    PostProcessor:SetPostProcessEffectAfter(PostProcessorEffects.MoonPulse, PostProcessorEffects.Lunacy)
    PostProcessor:SetPostProcessEffectAfter(PostProcessorEffects.MoonPulseGrading, PostProcessorEffects.MoonPulse)

    SetVisualEffect(nil) -- enables ColourCube, disables ColourCubeRingDistort/ColourCubeLineDistort
    --[[
    CurrentOrder:
    ZoomBlur
    Bloom
    Distort
    ColourCube --Base Effect (including special effect variations)
    Lunacy
    MoonPulse
    MoonPulseGrading
    --]]

    local postinitfns = ModManager:GetPostInitFns("ModShadersSortAndEnable")
    for i, fn in ipairs(postinitfns) do
        fn()
    end
end

local activeVisualEffect

function SetVisualEffect(effect)
	local target = effect or PostProcessorEffects.ColourCube
	if target == activeVisualEffect then
		return
	end
--	local specialEffects = { PostProcessorEffects.ColourCube, PostProcessorEffects.ColourCubeRingDistort, PostProcessorEffects.ColourCubeLineDistort }
	local specialEffects = { PostProcessorEffects.ColourCube, PostProcessorEffects.ColourCubeLineDistort }
	for _, id in ipairs(specialEffects) do
		PostProcessor:EnablePostProcessEffect(id, id == target)
	end
	activeVisualEffect = target
end

--------------------------------------------------------------------------

local _visualeffect_guid = 0
function GetNextVisualEffectGUID()
	_visualeffect_guid = _visualeffect_guid + 1
	return _visualeffect_guid
end

function PushLineDistortion(guid, x1, y1, x2, y2, aspect_ratio, width, displacement)
	if guid ~= _visualeffect_guid then
		return false
	end
	local distortion_modifier = Profile:GetDistortionModifier()
	if distortion_modifier <= 0 then
		PostProcessor:SetLineDistortDistortionParams(0, 0)
		SetVisualEffect(nil)
		return false
	end

	SetVisualEffect(PostProcessorEffects.ColourCubeLineDistort)

	PostProcessor:SetLineDistortLineParams(x1, y1, x2, y2, aspect_ratio)
	PostProcessor:SetLineDistortDistortionParams(width * distortion_modifier, displacement * distortion_modifier)

	return true
end

function ClearLineDistortion(guid)
	if guid == _visualeffect_guid then
		PostProcessor:SetLineDistortDistortionParams(0, 0)
		SetVisualEffect(nil)
	end
end

--------------------------------------------------------------------------

function PushRingDistortion(guid, x1, y1, x2, y2, aspect_ratio,
	inner_radius, outer_radius, ring_width_inner, ring_width_outer,
	spacing_power, inner_fade_amount, displacement_strength,
	ring_count, phase)

	if guid ~= _visualeffect_guid then
		return false
	end
	local distortion_modifier = Profile:GetDistortionModifier()
	if distortion_modifier <= 0 then
		SetVisualEffect(nil)
		return false
	end

	SetVisualEffect(PostProcessorEffects.ColourCubeRingDistort)

	PostProcessor:SetRingDistortPoints(x1, y1, x2, y2)
	PostProcessor:SetRingDistortRadii(inner_radius, outer_radius, ring_width_inner, ring_width_outer)
	PostProcessor:SetRingDistortShapeParams(spacing_power, inner_fade_amount, displacement_strength, aspect_ratio)
	PostProcessor:SetRingDistortRingCount(ring_count)
	PostProcessor:SetRingDistortPhase(phase)

	return true
end


function ClearRingDistortion(guid)
	if guid == _visualeffect_guid then
		SetVisualEffect(nil)
	end
end

------------------------------- Effect Template --------------------------
local easing = require("easing")

-- a large ripple where outer size eases outQuad and inner inQuad, 5 rings, no phasing
function Effect_BossRipple(t, scale)
    scale = scale or 1

    local start_radius = 0.05 -- shared starting radius for both inner and outer
    local max_radius = 1.5
    local ring_width_inner = 0.006
    local start_ring_width_outer = 0.01
    local end_ring_width_outer = 0.2
    local spacing_power = 2.0
    local inner_fade_amount = 1.0
    local displacement_strength = 0.1
    local ring_count = 5
    local phase = 0

    local outer_t = easing.outQuad(t, 0, 1, 1)
    local inner_t = easing.inQuad(t, 0, 1, 1)

    local inner_radius = start_radius + (max_radius - start_radius) * inner_t
    local outer_radius = start_radius + (max_radius - start_radius) * outer_t
    local ring_width_outer = start_ring_width_outer + (end_ring_width_outer - start_ring_width_outer) * outer_t

    return inner_radius * scale, outer_radius * scale, ring_width_inner * scale, ring_width_outer * scale, spacing_power, inner_fade_amount, displacement_strength * scale, ring_count, phase
end

