%% 1. シート名を指定してデータを読み込む
filename = 'all_データ整理_8_mirror2.xlsx'; 
sheetName = 'Analysis_Data(SD)'; % 回答距離のシート
opts = detectImportOptions(filename, 'Sheet', sheetName);
opts.VariableNamingRule = 'preserve'; % 日本語ヘッダー維持
T = readtable(filename, opts);

%% 2. 変数の抽出
try
    Condition = T.('条件');       % 合成条件
    TargetDist = T.('目標距離');  % 目標距離
    ResponseDist = T.('SD');% 回答距離
catch
    warning('列名での読み込みに失敗しました。列番号(3,4,5)を使用します。');
    Condition = T{:, 3}; 
    TargetDist = T{:, 4};
    ResponseDist = T{:, 5};
end

%% 3. データの前処理
% 0以下の値（エラーや頭内定位）を除外
valid_idx = ResponseDist > 0;
y = ResponseDist(valid_idx);   % 従属変数
g1 = Condition(valid_idx);     % 要因1：合成条件
g2 = TargetDist(valid_idx);    % 要因2：目標距離

%% 4. 二元配置分散分析 (Two-way ANOVA)
[p, tbl, stats] = anovan(y, {g1, g2}, ...
    'model', 'interaction', ...
    'varnames', {'Condition', 'TargetDistance'});

% 結果テーブルの表示
disp('--- 分散分析表 (ANOVA Table) ---');
disp(tbl);

%% 5. 結果の可視化と多重比較

% --- A. 多重比較（条件間の全体的な差） ---
% 修正点1: multcompareを2回呼ぶと図が2つ出るので、1回にまとめました
figure('Name', '多重比較 (Condition)');
[c, m, h, gn] = multcompare(stats, 'Dimension', 1); 
title('条件間の多重比較 (Main Effect of Condition)');

% コンソールに見やすく結果を表示
disp('--- 多重比較の結果 (p値 < 0.05 なら有意差あり) ---');
disp('   Group1     Group2    LowerCI      Diff     UpperCI    p-value');
disp(c);

% --- B. 交互作用プロット ---
% 修正点2: グラフの軸の並び順を変更しました
% 距離知覚の実験では「X軸：目標距離」「折れ線：条件」の方が見やすいため
figure('Name', '交互作用プロット');
interactionplot(y, {g2, g1}, 'varnames', {'TargetDistance', 'Condition'}); 
title('交互作用プロット (距離 x 条件)');
ylabel('平均回答距離 [m]');
grid on;
%% 6. [プレゼン用] 要因ごとのグラフ作成（文字サイズ特大）
% プレゼンテーション用に、条件別と距離別のグラフを個別に作成します。

% --- 共通設定（フォントサイズや色） ---
fs_axis = 28;      % 軸の数字の大きさ
fs_label = 32;     % 軸ラベルの大きさ
fs_title = 32;     % タイトルの大きさ
line_w = 2.5;      % 線の太さ
marker_s = 15;     % マーカーサイズ
color_stable = [0.7 0.7 0.7]; % 青（安定）
color_bad    = [0.3 0.3 0.3]; % 赤（不安定）
color_neutral= [0.5 0.5 0.5]; % グレー（距離用）


%  Graph 1: 条件（Condition）による違い

% 統計量（平均と標準誤差）を計算
[mean_c, sem_c, gname_c] = grpstats(y, g1, {'mean', 'sem', 'gname'});
x_c = 1:length(mean_c);
labels_c = {'A', 'B', 'C', 'D', 'E', 'F'}; 

figure('Name', 'MainEffect_Condition', 'Color', 'w', 'Position', [100, 100, 1000, 700]);
hold on;


b1 = bar(x_c, mean_c, 'FaceColor', 'flat');

% 色分け: D(4)とE(5)
b1.CData(1:4, :) = repmat(color_stable, 4, 1); % A,B,C
b1.CData(5:6, :) = repmat(color_bad, 2, 1);    % D,E (悪化)
%b1.CData(, :)   = color_stable;               % F (回復)

% エラーバー
errorbar(x_c, mean_c, sem_c, 'k.', 'LineWidth', line_w, 'CapSize', 20);

% 有意差スター（DとEの上）
txt_h = max(mean_c + sem_c) * 0.05; % 高さ調整
text(6, mean_c(6) + sem_c(6) + txt_h, '**', 'FontSize', 40, 'Color', 'k', 'HorizontalAlignment', 'center');
text(5, mean_c(5) + sem_c(5) + txt_h, '**', 'FontSize', 40, 'Color', 'k', 'HorizontalAlignment', 'center');

% 見た目の調整
ylabel('Standard Deviation (SD) [m]', 'FontSize', fs_label, 'FontWeight', 'bold');
xlabel('Condition', 'FontSize', fs_label, 'FontWeight', 'bold');
title('Effect of Synthesis Condition', 'FontSize', fs_title);
set(gca, 'FontSize', fs_axis, 'LineWidth', line_w, 'XTick', x_c, 'XTickLabel', labels_c, 'FontName', 'Arial');
grid on; box on;
hold off;



%  Graph 2: 目標距離（Target Distance）による違い

% 統計量（平均と標準誤差）を計算
[mean_d, sem_d, gname_d] = grpstats(y, g2, {'mean', 'sem', 'gname'});
% gname_d は文字列なので数値に変換
dist_vals = str2double(gname_d); 

figure('Name', 'MainEffect_Distance', 'Color', 'w', 'Position', [150, 150, 1000, 700]);
hold on;

% 棒グラフ描画
b2 = bar(dist_vals, mean_d, 'FaceColor', color_neutral, 'BarWidth', 0.6);

% エラーバー
errorbar(dist_vals, mean_d, sem_d, 'k.', 'LineWidth', line_w, 'CapSize', 20);

% 「有意差なし (n.s.)」のテキストを中心に配置
x_center = (min(dist_vals) + max(dist_vals)) / 2;
y_top = max(mean_d + sem_d) * 1.1;
text(x_center, y_top, 'n.s. (No Significant Difference)', ...
    'FontSize', 24, 'HorizontalAlignment', 'center', 'Color', 'k');

% 見た目の調整
ylabel('Standard Deviation (SD) [m]', 'FontSize', fs_label, 'FontWeight', 'bold');
xlabel('Target Distance [m]', 'FontSize', fs_label, 'FontWeight', 'bold');
title('Effect of Target Distance', 'FontSize', fs_title);
set(gca, 'FontSize', fs_axis, 'LineWidth', line_w, 'XTick', dist_vals, 'FontName', 'Arial');
ylim([0, y_top * 1.1]); % 上に余白を持たせる
grid on; box on;
hold off;