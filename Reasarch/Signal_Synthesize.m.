% [Condition C Final v8] Auto-Calibration OFF (DistCancel Only)
clc; close all; clear all; 
SOFAstart;
%% --- 1. Settings ---
SubjectName     = 'user name'; 
%↑被験者のHRIRデータを指定

use_RigidSphere = true; 
use_EC          = true;   % ON推奨
use_AngleCorr   = true;   % ON推奨
%↑HRTFの畳み込み方法を変更．true/falseで自由に変更できるが，
% AngleCorr(角度補正)はEC処理が前提となるのでEC/false, AngleCorr/trueの組み合わせは想定してません

gen_wav         = true;
NoiseDuration   = 2.0;    
% ★実験の安全性を担保する設定
TARGET_PEAK_AMPLITUDE = 0.5; % 最大振幅の目標値 (0.5 = -6dBFS)
% 近接効果によるピーク増大を見越して、入力レベルを下げておきます
RMS_TARGET            = 0.05; % 推奨値: 0.05 (0.2だと近距離で割れる可能性大)
% --- ディレクトリ等の設定 ---
if use_RigidSphere %剛体球
    dvf_type_sph = 'RigidSphereLimClip'; str_scat = 'Rigid';
else %自由音場
    dvf_type_sph = 'SphLimClip'; str_scat = 'Sph';
end
if use_EC, str_ec = 'EC_On'; else, str_ec = 'EC_Off'; end
if use_EC && use_AngleCorr, str_corr = 'Corr_On'; else, str_corr = 'Corr_Off'; end
dir_name = sprintf('CircularDVF_%s_%s_%s', str_scat, str_ec, str_corr);
base_dir = 'user directory';
%↑ファイルの出力先を指定します, 使うときはご自身の環境に合わせてください
%↓出力ファイル名を指定します
save_dir = fullfile(base_dir, 'Synthsize8', SubjectName, dir_name); 
if ~exist(save_dir, 'dir'), mkdir(save_dir); end
file_prefix = dir_name; 
fig_title_prefix = strrep(dir_name, '_', ' '); 
head_radius_m = 0.085; head_radius_cm = 8.5; % 8.5cm推奨
Fs = 48000; dist_init = 1.5; c = 343; Ns = 512; 
x_ear_left = [0, head_radius_m, 0]; x_ear_right = [0, -head_radius_m, 0];
disp(['Subject: ' SubjectName]);
disp(['Output Directory: ' save_dir]);
%% --- 2. Load DAT ---
disp('Loading DAT...'); 
Nazim = 72; 
h_left = zeros(Ns, Nazim, 1); h_right = zeros(Ns, Nazim, 1);
ang_step = 360 / Nazim;
azim_deg = (0 : Nazim-1) * ang_step;
hrir_root_path = 'user directory';
%↑HRIRデータの保存場所の指定です．通研の無響室で測定したHRTF測定のデータを引っ張ってきてください
%↓HRTRデータは水平面データ(elev0)が入ってると動くと思います.

base_path = fullfile(hrir_root_path, SubjectName, 'elev0');
for i = 1:Nazim
    ang = azim_deg(i); 
    if ang > 180, ang = ang - 360; end
    fn = ['0e', sprintf('%03d', ang), 'a_new.dat'];
    
    fid = fopen(fullfile(base_path, ['L', fn]), 'r', 'b'); 
    if fid == -1, error('File not found: L%s', fn); end
    h_left(:, i, 1) = fread(fid, Ns, 'float32'); fclose(fid);
    
    fid = fopen(fullfile(base_path, ['R', fn]), 'r', 'b'); 
    h_right(:, i, 1) = fread(fid, Ns, 'float32'); fclose(fid);
end
H_left_orig = fft(h_left); H_left_orig = H_left_orig(1:Ns/2+1, :, :); 
H_right_orig = fft(h_right); H_right_orig = H_right_orig(1:Ns/2+1, :, :);
%% --- 3. DVF Calculation ---
% 距離設定
dist_final = [0.35, 0.50, 0.70, 1.00, 1.5]; 
Ndist_final = length(dist_final);
disp(['Calculating DVF (' dvf_type_sph ')...']);
D_sph_m = zeros(Ns/2+1, Nazim, Ndist_final);
t = (0:Ns-1)/Fs; f = (0:Ns/2)*Fs/Ns; k = 2*pi*f/c; 
m = -Nazim/2 : Nazim/2-1; M = Nazim + mod(Nazim, 2); ind_k = 2:Ns/2+1;
dvf_val_type = 'complex'; dvf_norm_type = 'sch'; ref_ear_pos = x_ear_left;
parfor J = (Nazim-M)/2+(1:M)
    for K = 1:Ndist_final
        if contains(dvf_type_sph, 'RigidSphere')
            d_val = dvf(dist_init, dist_final(K), k(ind_k), m(J), 2, dvf_type_sph, ...
                        0, ref_ear_pos, dvf_val_type, dvf_norm_type);
        else
            d_val = dvf(dist_init, dist_final(K), k(ind_k), m(J), 2, dvf_type_sph, 0); 
        end
        % dist_gain is handled by DVF physics, but we cancel it later in Section 4.
        D_sph_m(ind_k, J, K) = d_val.';
    end
end
% Adaptive Filter
epsilon = 1e-4; 
kr = k(ind_k).' * head_radius_m; kr(kr < 1e-10) = 1e-10; 
L_cutoff = floor(kr + 0.5*(real(log(1/epsilon^3)+log(kr)).^(2/3)).*(kr.^(1/3)));
Mask = ones(size(D_sph_m));
for f_idx = 1:length(ind_k)
    limit_m = L_cutoff(f_idx);
    idx_cut = find(abs(m) > limit_m);
    if ~isempty(idx_cut), Mask(f_idx, idx_cut, :) = 0; end
end
D_sph_m = D_sph_m .* Mask;
%% --- 4. Synthesis (Corrected with Distance Gain Cancel) ---
disp('Synthesizing...');
[Nbins, Nazim_org] = size(H_left_orig);
H_L_fin_all = zeros(Nbins, Nazim_org, Ndist_final);
H_R_fin_all = zeros(Nbins, Nazim_org, Ndist_final);
% --- 距離ごとのループ処理 ---
for dist_idx = 1:Ndist_final
    current_dist = dist_final(dist_idx); 
    
    % 1. 視差補正 (EC)
    if use_EC
        [x1_full, x2_full] = transope_sekizawa(current_dist, k, head_radius_cm); 
        idx_extract = 1 : 5 : 360; 
        x1 = x1_full(:, idx_extract); 
        x2 = x2_full(:, idx_extract);
    else
        x1 = 1; x2 = 1; 
    end
    % 2. 角度補正 (AngleCorr)
    if use_EC && use_AngleCorr
        th_orig = deg2rad(azim_deg);
        src_x = current_dist * cos(th_orig); 
        src_y = current_dist * sin(th_orig);
        ear_L = [0, head_radius_m]; ear_R = [0, -head_radius_m];
        vec_L_x = src_x - ear_L(1); vec_L_y = src_y - ear_L(2);
        vec_R_x = src_x - ear_R(1); vec_R_y = src_y - ear_R(2);
        th_L_new = mod(atan2(vec_L_y, vec_L_x), 2*pi);
        th_R_new = mod(atan2(vec_R_y, vec_R_x), 2*pi);
        
        ext_idx = [Nazim, 1:Nazim, 1];
        th_ext = [th_orig(end)-2*pi, th_orig, th_orig(1)+2*pi];
        H_L_ext = H_left_orig(:, ext_idx); H_R_ext = H_right_orig(:, ext_idx);
        
        H_left_use = interp1(th_ext, H_L_ext.', th_L_new, 'linear').';
        H_right_use = interp1(th_ext, H_R_ext.', th_R_new, 'linear').';
    else
        H_left_use = H_left_orig;
        H_right_use = H_right_orig;
    end
    % 3. 合成処理 (Circular Convolution)
    H_L_cm = cft(H_left_use .* x1, 2);
    H_R_cm = cft(H_right_use .* x2, 2);
    
    curr_D = squeeze(D_sph_m(:, :, dist_idx));
    
    H_L_out = icft(curr_D .* H_L_cm, 2);
    H_R_out = icft(curr_D .* H_R_cm, 2);
    
    % 【距離減衰キャンセル】
    % 物理的な1/r則をキャンセルし、散乱・近接効果（スペクトル変化）のみを残す
    %dist_gain_cancel = current_dist / dist_init;
    
    %H_L_out = H_L_out * dist_gain_cancel;
    %H_R_out = H_R_out * dist_gain_cancel;
    % 
    %↑先行研究のdvfで既に1/r則（音圧の距離減衰）がキャンセルアウトされていた

    H_L_fin_all(:, :, dist_idx) = H_L_out;
    H_R_fin_all(:, :, dist_idx) = H_R_out;
end
% --- 時間領域へ変換 ---
h_L_fin = zeros(512, Nazim, Ndist_final);
h_R_fin = zeros(512, Nazim, Ndist_final);
for d = 1:Ndist_final
    spec_L = H_L_fin_all(:,:,d);
    spec_R = H_R_fin_all(:,:,d);
    full_spec_L = [spec_L; conj(spec_L(end-1:-1:2, :))];
    full_spec_R = [spec_R; conj(spec_R(end-1:-1:2, :))];
    h_L_fin(:,:,d) = real(ifft(full_spec_L));
    h_R_fin(:,:,d) = real(ifft(full_spec_R));
end
% --- Save MAT Data ---
comp_mat_name = [dir_name, '_Data.mat'];
H_L_fin = H_L_fin_all; H_R_fin = H_R_fin_all;
save(fullfile(save_dir, comp_mat_name), 'H_L_fin', 'H_R_fin', 'D_sph_m', 'dist_final', 'f', 'Fs');
%% --- 5. Save WAV (No Normalization) ---
% ランダムなホワイトノイズを生成して畳み込んでいます
% 各距離/角度ごとに違う音色を生成します
if gen_wav
    disp('Generating WAV files with Unique White Noise...');
    rng(42); 
    NumRepetitions = 6;
    
    ObjBase = SOFAgetConventions('SimpleFreeFieldHRIR');
    ObjBase.Data.SamplingRate = Fs; 
    ObjBase.ReceiverPosition = [x_ear_left; x_ear_right];
    ObjBase.ListenerPosition = [0 0 0];
    
    L_noise = round(Fs * NoiseDuration);
    fade_len = round(0.05 * Fs); 
    win = ones(L_noise, 1);
    win(1:fade_len) = linspace(0, 1, fade_len);
    win(end-fade_len+1:end) = linspace(1, 0, fade_len);
    for dist_idx = 1:Ndist_final
        current_dist = dist_final(dist_idx);
        curr_h_L = squeeze(h_L_fin(:, :, dist_idx));
        curr_h_R = squeeze(h_R_fin(:, :, dist_idx));
        
        % SOFA Save
        Obj = ObjBase;
        Obj.Data.IR = zeros(Nazim, 2, Ns);
        Obj.Data.IR(:, 1, :) = curr_h_L.'; Obj.Data.IR(:, 2, :) = curr_h_R.'; 
        Obj.SourcePosition = [ (0:5:355)', zeros(Nazim, 1), repmat(current_dist, [Nazim, 1]) ];
        fn_out = sprintf('%s_%0.2fm.sofa', file_prefix, current_dist);
        SOFAsave(fullfile(save_dir, fn_out), Obj);
        
        % WAV Save
        wav_dist_dir = fullfile(save_dir, 'wav', sprintf('%.2fm', current_dist));
        if ~exist(wav_dist_dir, 'dir'), mkdir(wav_dist_dir); end
        
        parfor ang_idx = 1:Nazim
            ang = azim_deg(ang_idx);
            
            for rep_i = 1:NumRepetitions
                % ノイズ生成
                raw_sig = randn(L_noise, 1);
                raw_rms = rms(raw_sig);
                source_sig = (raw_sig / raw_rms) * RMS_TARGET .* win;
    
                % 畳み込み
                out_L = fftfilt(curr_h_L(:, ang_idx), source_sig);
                out_R = fftfilt(curr_h_R(:, ang_idx), source_sig);
            
                
                % 正規化なしで結合
                out_sig = [out_L, out_R];
                
                % リミッター (クリッピング防止のみ)
                max_val = max(abs(out_sig(:)));
                if max_val > 0.99
                    out_sig = out_sig / max_val * 0.99;
                end
                
                % 保存
                wav_fn = sprintf('%s_%.2fm_%03ddeg_rep%d.wav', file_prefix, current_dist, ang, rep_i);
                audiowrite(fullfile(wav_dist_dir, wav_fn), out_sig, Fs);
            end
        end
    end
end
%% --- 6. Visualization (Optional) ---
%通常のHRTFと周波数ごとの距離と音圧レベルを描画しています
%今回は距離減衰を反映していないので縦線が表示されれば問題ないです
lbl_FS = 18; ttl_FS = 20; ax_FS  = 16; 
fig_save_dir = fullfile(save_dir, 'figure');
if ~exist(fig_save_dir, 'dir'), mkdir(fig_save_dir); end
% (1) Azimuth Spectrum @ 1.0m
vis_dist = 1.0; 
[~, vi] = min(abs(dist_final - vis_dist));
half_idx = ceil(Nazim/2); 
idx_cen = [ (half_idx+2):Nazim, 1:(half_idx+1) ]; 
azim_cen = -175 : 5 : 180;
H_vis = fft(squeeze(h_L_fin(:, :, vi))); 
H_vis = H_vis(1:floor(Ns/2)+1, idx_cen);
f_vis = (0:floor(Ns/2)) * Fs / Ns; 
fig1 = figure('Name', 'Azimuth Spectrum', 'Color', 'w', 'Position', [100 100 600 500]);
surface(f_vis*1e-3, azim_cen, 20*log10(abs(H_vis)).', 'EdgeColor', 'none'); 
view(2); shading interp; axis tight; colormap(jet);
title([strrep(file_prefix, '_', ' ') ' @ 1.0m'], 'FontSize', ttl_FS, 'Interpreter', 'none');
xlabel('Freq(kHz)', 'FontSize', lbl_FS); ylabel('Azimuth(deg)', 'FontSize', lbl_FS);
xlim([0.1 20]); ylim([-175 180]); 
set(gca,'XScale','linear','CLim',[-25 25], 'FontSize', ax_FS); 
colorbar('FontSize', ax_FS);
saveas(fig1, fullfile(fig_save_dir, [file_prefix '_LeftSpec.png']));
% (2) Distance Variation @ 90deg
target_ang = 90; 
[~, ai] = min(abs((0:5:355) - target_ang));
H_dist = fft(squeeze(h_L_fin(:, ai, :))); 
H_dist = H_dist(1:floor(Ns/2)+1, :);
fig2 = figure('Name', 'Distance Variation', 'Color', 'w', 'Position', [750 100 600 500]);
surface(f_vis*1e-3, dist_final*100, 20*log10(abs(H_dist)).', 'EdgeColor', 'none');
view(2); shading interp; axis tight; colormap(jet);
title([strrep(file_prefix, '_', ' ') ' DistVar'], 'FontSize', ttl_FS, 'Interpreter', 'none');
xlabel('Freq(kHz)', 'FontSize', lbl_FS); ylabel('Dist(cm)', 'FontSize', lbl_FS);
xlim([0.1 20]); ylim([min(dist_final)*100 max(dist_final)*100]); 
set(gca,'XScale','log','YScale','linear','CLim',[-25 25], 'FontSize', ax_FS); 
colorbar('FontSize', ax_FS);
saveas(fig2, fullfile(fig_save_dir, [file_prefix '_DistVar.png']));
disp('Figures saved.');
disp('Distance_experiment Done.');
