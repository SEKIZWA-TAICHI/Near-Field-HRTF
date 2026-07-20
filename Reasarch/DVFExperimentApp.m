classdef DVFExperimentApp < handle
    % 再生音に影響する箇所はゲイン設定くらいですが，音圧校正してその後いじらなければ問題ないと思います
    % DVFExperimentApp_kanseiban2 実験アプリ
    % (統合版: UIデザイン + 360°回転確認(停止機能付) + 詳細ログ記録)
    
    properties
        % --- 設定 ---
        SaveDir = fullfile(pwd, 'data_dvf');
        DeadzoneRatio = 0.05;      
        MaxDistance = 2.2;         % 表示最大距離 (m)
        FixationTimeRange = [1.0, 1.5]; 
        PreSilence = 0.5;          
        
        TrialsPerCondition = 6;    % 各音源の試行回数
        GlobalGain = 1.0;          % デジタルゲイン
        
        % --- 固定回答ポイントの設定 (本番用) ---
        GridDistances = [0.35, 0.50, 0.71, 1.00, 1.41, 2.0];      
        GridAngles    = [0, 45, 90, 135, 180];  % 指定の5角度
        
        % --- 管理フラグ ---
        IsRotationMode = false;    % 360°回転再生中かどうか
        StopRequested = false;     % 停止ボタンが押されたかのフラグ
        IsPracticeMode = false;    
        CurrentTrialIdx = 0
        TrialList          
        PracticeList       
        SubjectName = 'TestSubject';
        ExperimentLog
        LblProgress  % 進捗表示用ラベル
        % --- ウィンドウ ---
        ControlFig   
        SubjectFig   
        
        % --- UIコンポーネント ---
        ExperimentPanel
        ResponseAxes
        FixationText
        SetupPanel
        ControlPanel
        MonitorPanel     
        MonitorAxes      
        StatusLabel
        StartBtn
        PracticeBtn
        StopBtn
        LogTextArea
        
        % --- 音声 ---
        Player
    end
    
    methods
        function app = DVFExperimentApp()
            app.createDualWindows();
            app.log('アプリケーション起動: 待機中...');
        end
        
        
        % 画面構築
       
        function createDualWindows(app)
            mp = get(0, 'MonitorPositions'); 
            mainMonitorIdx = 1; subMonitorIdx = 1;
            if size(mp, 1) > 1
                if mp(1, 1) == 1 && mp(1, 2) == 1
                    mainMonitorIdx = 1; subMonitorIdx = 2;
                else
                    mainMonitorIdx = 2; subMonitorIdx = 1; 
                end
            end
            
            ctrlW = 380; ctrlH = 700; 
            mainPos = mp(mainMonitorIdx, :);
            ctrlX = mainPos(1) + (mainPos(3)-ctrlW)/2;
            ctrlY = mainPos(2) + (mainPos(4)-ctrlH)/2;
            
            app.ControlFig = uifigure('Name', '実験操作パネル', ...
                'Position', [ctrlX, ctrlY, ctrlW, ctrlH], ...
                'CloseRequestFcn', @app.onCloseApp);
            
            grid = uigridlayout(app.ControlFig, [4, 1]);
            grid.RowHeight = {'fit', 'fit', 250, '1x'};
            
            app.SetupPanel = uipanel(grid, 'Title', '設定・ロード');
            sGrid = uigridlayout(app.SetupPanel, [7, 2]); 
            
            uibutton(sGrid, 'Text', '被験者名設定', 'ButtonPushedFcn', @app.onSetSubject);
            uilabel(sGrid, 'Text', ''); 
            
            uibutton(sGrid, 'Text', '定位確認用WAV選択', ...
                'ButtonPushedFcn', @app.onLoadPracticeFolder, 'BackgroundColor', [0.8 0.9 1.0]); 
            app.PracticeBtn = uibutton(sGrid, 'Text', '360°回転音再生', ...
                'ButtonPushedFcn', @app.onStartRotationCheck, 'Enable', 'off', ...
                'BackgroundColor', [0.2 0.4 0.8], 'FontColor','w');
            
            app.StopBtn = uibutton(sGrid, 'Text', '再生停止', ...
                'ButtonPushedFcn', @app.onStopPlayback, 'Enable', 'off', ...
                'BackgroundColor', [0.8 0.2 0.2], 'FontColor', 'w');
            uilabel(sGrid, 'Text', '←回転再生を中断');

            uibutton(sGrid, 'Text', '本番用WAV選択', 'ButtonPushedFcn', @app.onLoadWavFolder);
            app.StartBtn = uibutton(sGrid, 'Text', '本番実験開始', ...
                'BackgroundColor', [0, 0.6, 0], 'FontColor', 'w', 'FontWeight', 'bold', ...
                'Enable', 'off', 'ButtonPushedFcn', @app.onStartExperiment);

            uibutton(sGrid, 'Text', 'テスト音再生 (1kHz)', 'ButtonPushedFcn', @app.onPlayTestTone);
            uilabel(sGrid, 'Text', '←音量調整用');
            
            app.StatusLabel = uilabel(sGrid, 'Text', '準備中...');
            app.StatusLabel.Layout.Column = [1 2];
            
            app.ControlPanel = uipanel(grid, 'Title', 'コントロール');
            cGrid = uigridlayout(app.ControlPanel, [1, 1]);
            uibutton(cGrid, 'Text', '強制終了 / リセット', ...
                'ButtonPushedFcn', @app.onReset, 'FontColor', 'r');
            
            app.MonitorPanel = uipanel(grid, 'Title', '回答モニター (緑:正解 / 赤:回答)');
            mGrid = uigridlayout(app.MonitorPanel, [1, 1]);
            app.MonitorAxes = uiaxes(mGrid);
            app.MonitorAxes.Color = [0.95 0.95 0.95];
            app.MonitorAxes.XColor = 'none'; app.MonitorAxes.YColor = 'none';
            app.MonitorAxes.DataAspectRatio = [1 1 1];
            app.MonitorAxes.XLim = [-app.MaxDistance*1.1, app.MaxDistance*1.1];
            app.MonitorAxes.YLim = [-app.MaxDistance*1.1, app.MaxDistance*1.1];
            
            lPanel = uipanel(grid, 'Title', 'ログ');
            lGrid = uigridlayout(lPanel, [1,1]);
            app.LogTextArea = uitextarea(lGrid, 'Editable', 'off');
            
            subPos = mp(subMonitorIdx, :);
            app.SubjectFig = uifigure('Name', '被験者画面', 'Color', 'k', ...
                'Position', subPos, 'AutoResizeChildren', 'off', 'CloseRequestFcn', @(s,e) 0);
            drawnow;

            



            app.SubjectFig.WindowState = 'fullscreen';
            
            app.ExperimentPanel = uipanel(app.SubjectFig, 'BackgroundColor', 'k', 'BorderType', 'none', ...
                'Units', 'normalized', 'Position', [0 0 1 1]); 
            
            app.FixationText = uilabel(app.ExperimentPanel, 'Text', '+', 'FontColor', 'w', 'FontSize', 60, ...
                'HorizontalAlignment', 'center', 'Visible', 'off');
            
            app.ResponseAxes = uiaxes(app.ExperimentPanel);
            app.ResponseAxes.Color = 'k'; 
            app.ResponseAxes.XColor = 'none'; app.ResponseAxes.YColor = 'none';
            app.ResponseAxes.DataAspectRatio = [1 1 1];
            app.ResponseAxes.ButtonDownFcn = @app.onAxesClick;
            disableDefaultInteractivity(app.ResponseAxes);
            app.ResponseAxes.Visible = 'off';

            %追加コード
            % 被験者用 進捗表示ラベルの作成 (左下に配置)
            app.LblProgress = uilabel(app.ExperimentPanel);
            app.LblProgress.Position = [20 20 300 40]; % [左 下 幅 高さ]
            app.LblProgress.Text = '';
            app.LblProgress.FontSize = 20;
            app.LblProgress.FontColor = [0.5 0.5 0.5]; % グレー
            % 
            
            app.SubjectFig.SizeChangedFcn = @app.onResizeSubject;
            app.onResizeSubject([], []);

        end
        
        
        % 制御ロジック
        function onResizeSubject(app, ~, ~)
            app.SubjectFig.Units = 'pixels';
            p = app.SubjectFig.Position; 
            w_pix = p(3); h_pix = p(4);
            app.FixationText.Position = [1, 1, w_pix, h_pix];
            
            if w_pix > h_pix
                h_norm = 0.9; w_norm = 0.9 * (h_pix / w_pix);
            else
                w_norm = 0.9; h_norm = 0.9 * (w_pix / h_pix);
            end
            app.ResponseAxes.Units = 'normalized';
            app.ResponseAxes.Position = [(1-w_norm)/2, (1-h_norm)/2, w_norm, h_norm];
            
            range_m = app.MaxDistance * 1.1; 
            if app.IsRotationMode
                app.ResponseAxes.XLim = [-range_m, range_m];      
            else
                app.ResponseAxes.XLim = [-range_m, range_m * 0.2]; 
            end
            app.ResponseAxes.YLim = [-range_m, range_m];
            
            if strcmp(app.ResponseAxes.Visible, 'on')
                app.showResponseUI([]);
            end
        end

        function onReset(app, ~, ~)
            app.IsRotationMode = false;
            app.StopRequested = false;
            app.IsPracticeMode = false;
            app.ResponseAxes.Visible = 'off';
            app.FixationText.Visible = 'off';
            app.StartBtn.Enable = 'on';
            app.StopBtn.Enable = 'off';
            if ~isempty(app.PracticeList), app.PracticeBtn.Enable = 'on'; end
            app.onResizeSubject([],[]);
            app.log('リセット完了。');
        end

        function onSetSubject(app, ~, ~)
            ans = inputdlg('被験者名', 'Subject', [1 50], {app.SubjectName});
            if ~isempty(ans), app.SubjectName = ans{1}; end
        end

        function onStopPlayback(app, ~, ~)
            app.StopRequested = true;
            if ~isempty(app.Player) && isplaying(app.Player)
                stop(app.Player);
            end
            app.log('再生停止がリクエストされました。');
        end

        % データロード
        function onLoadPracticeFolder(app, ~, ~)
            folder = uigetdir(pwd, '【定位確認用】フォルダを選択');
            if folder == 0, return; end
            files = dir(fullfile(folder, '**', '*.wav')); 
            app.PracticeList = struct('dist', {}, 'angle', {}, 'condition', {}, 'filepath', {});
            
            %修正: 正規表現を新しいファイル名形式に対応させる
            
            pattern = '^(.*)_([\d\.]+)m_(\d+)deg.*\.wav$'; 
       
            
            for i = 1:length(files)
                tokens = regexp(files(i).name, pattern, 'tokens');
                if ~isempty(tokens)
                    newTrial.condition = tokens{1}{1};
                    newTrial.dist = str2double(tokens{1}{2});
                    newTrial.angle = str2double(tokens{1}{3});
                    newTrial.filepath = fullfile(files(i).folder, files(i).name);
                    app.PracticeList(end+1) = newTrial;
                end
            end
            if ~isempty(app.PracticeList)
                app.PracticeBtn.Enable = 'on';
                app.log('定位確認用データをロードしました。');
            end
        end

        function onLoadWavFolder(app, ~, ~)
            folder = uigetdir(pwd, '【本番用】親フォルダを選択');
            if folder == 0, return; end
            files = dir(fullfile(folder, '**', '*.wav')); 
            app.TrialList = struct('dist', {}, 'angle', {}, 'condition', {}, 'filepath', {});
            
            %正規表現パターンを変更
        
            %最後に任意の文字を含めるように変更
            pattern = '^(.*)_([\d\.]+)m_(\d+)deg.*\.wav$'; 
            
            
            for i = 1:length(files)
                tokens = regexp(files(i).name, pattern, 'tokens');
                if ~isempty(tokens)
                    aVal = mod(str2double(tokens{1}{3}), 360);
                    if any(abs(app.GridAngles - aVal) < 0.1)
                        newTrial.condition = tokens{1}{1};
                        newTrial.dist = str2double(tokens{1}{2});
                        newTrial.angle = aVal;
                        newTrial.filepath = fullfile(files(i).folder, files(i).name);
                        app.TrialList(end+1) = newTrial;
                    end
                end
            end
            if ~isempty(app.TrialList)
                app.StartBtn.Enable = 'on';
                app.log(sprintf('本番用 %d ファイルロード完了。', length(app.TrialList)));
            end
        end

      
        % 実行制御 (回転確認)
        function onStartRotationCheck(app, ~, ~)
            if isempty(app.PracticeList), return; end
            
            app.IsRotationMode = true;
            app.StopRequested = false;
            app.StopBtn.Enable = 'on';
            app.PracticeBtn.Enable = 'off';
            app.StartBtn.Enable = 'off';
            app.onResizeSubject([], []);
            
            % --- 再生リストの作成ロジック改良 ---
            targetRotAngles = 0:45:315; % 再生したい角度の順番
            
            % 基準となる距離を探す (リストの中で 1.0m に最も近いもの)
            dists = [app.PracticeList.dist];
            [~, idx] = min(abs(dists - 1.0)); 
            targetDist = app.PracticeList(idx).dist;
            
            rotList = app.PracticeList([]); % 空の構造体を用意
            
            %各角度について「最初の1個」だけを探してリストに追加
            for tAng = targetRotAngles
                % 条件に合うファイルを検索
                found = false;
                for i = 1:length(app.PracticeList)
                    trial = app.PracticeList(i);
                    % 距離が一致 かつ 角度が一致
                    if abs(trial.dist - targetDist) < 0.01 && ...
                       abs(trial.angle - tAng) < 0.1
                   
                        rotList(end+1) = trial; %#ok<AGROW>
                        found = true;
                        break; % 1つ見つかったらこの角度は終了（rep2以降は無視）
                    end
                end
                if ~found
                    app.log(sprintf('警告: %.2fm, %d deg のファイルが見つかりません', targetDist, tAng));
                end
            end
           
            
            % 0度に戻ってくる演出用 (リストの最後に0度があれば追加)
            if ~isempty(rotList) && rotList(1).angle == 0
                rotList(end+1) = rotList(1);
            end

            if isempty(rotList)
                app.log('エラー: 再生可能なファイルが見つかりません。');
                app.onReset([],[]); return;
            end
            
            app.log(sprintf('--- 360°回転再生開始 (%.2fm) ---', targetDist));
            
            % --- 再生ループ ---
            app.ResponseAxes.Visible = 'on';
            for i = 1:length(rotList)
                if app.StopRequested, break; end
                trial = rotList(i);
                
                app.showResponseUI([]); 
                
                % 現在の位置を緑丸で表示
                hold(app.ResponseAxes, 'on');
                rad = deg2rad(trial.angle + 90);
                plot(app.ResponseAxes, trial.dist*cos(rad), trial.dist*sin(rad), ...
                    'go', 'MarkerSize', 20, 'LineWidth', 4);
                hold(app.ResponseAxes, 'off');
                
                app.log(sprintf('再生中: %d deg', trial.angle));
                
                [y, fs] = audioread(trial.filepath);
                app.Player = audioplayer(y * app.GlobalGain, fs);
                play(app.Player);
                
                % 再生終了待ち（中断監視付き）
                while isplaying(app.Player)
                    if app.StopRequested
                        stop(app.Player);
                        break; 
                    end
                    drawnow; pause(0.05);
                end
                
                if app.StopRequested, break; end
                pause(0.2); % 次の音までの間隔
            end
            
            app.log('--- 回転音セッション終了 ---');
            app.onReset([],[]);
        end

        
        % 実行制御 (本番)
        
        function onStartExperiment(app, ~, ~)
            app.IsRotationMode = false;
            app.onResizeSubject([], []);
            baseList = app.TrialList;
            %修正: repmat を削除し、そのまま使う
            
            
            fullList = baseList; % フォルダ内の全ファイル(_rep含む)をそのまま使用
            
            app.TrialList = fullList(randperm(length(fullList)));
            app.CurrentTrialIdx = 0;
            app.ExperimentLog = table(); 
            app.StartBtn.Enable = 'off';
            app.PracticeBtn.Enable = 'off';
            app.log('--- 本番実験開始 ---');
            app.nextTrial();
        end
        
        function nextTrial(app)
            app.CurrentTrialIdx = app.CurrentTrialIdx + 1;
            if app.CurrentTrialIdx > length(app.TrialList)
                app.finishExperiment(); return;
            end

            %追加コード: 進捗表示の更新
            app.LblProgress.Text = sprintf('Trial %d / %d', ...
                app.CurrentTrialIdx, length(app.TrialList));
            

            trial = app.TrialList(app.CurrentTrialIdx);
            app.log(sprintf('試行 %d/%d: %.2fm, %d deg', app.CurrentTrialIdx, length(app.TrialList), trial.dist, trial.angle));
            app.ResponseAxes.Visible = 'off';
            app.FixationText.Text = '+';
            app.FixationText.Visible = 'on';
            drawnow;
            rawTime = app.FixationTimeRange(1) + rand() * diff(app.FixationTimeRange);
            t = timer('StartDelay', round(rawTime, 3), 'TimerFcn', @(~,~) app.playStimulus(trial));
            start(t);
        end
        
        function playStimulus(app, trial)
            app.FixationText.Visible = 'off';
            drawnow;
            [y, fs] = audioread(trial.filepath);
            app.Player = audioplayer(y * app.GlobalGain, fs);
            playblocking(app.Player);
            app.showResponseUI([]); 
        end

      
        % UI描画
      
        
        function showResponseUI(app, ~)
            % 軸のプロパティを再設定（念のため毎回黒に指定）
            app.ResponseAxes.Color = 'k'; 
            cla(app.ResponseAxes);
            hold(app.ResponseAxes, 'on');
            
            if app.IsRotationMode
                theta = linspace(0, 2*pi, 100); 
            else
                theta = linspace(pi/2, 3*pi/2, 100); 
            end
            
            % ガイド円
            ticks = 0.5 : 0.5 : app.MaxDistance;
            for r = ticks
                plot(app.ResponseAxes, r*cos(theta), r*sin(theta), ...
                    'Color', [0.4 0.4 0.4], 'LineStyle', ':', 'LineWidth', 2.0, 'HitTest', 'off');
                text(app.ResponseAxes, r*cos(pi), r*sin(pi), sprintf('%.1fm', r), ...
                    'Color', 'w', 'FontSize', 14, 'HitTest', 'off');
            end
            
            % Frontライン
            plot(app.ResponseAxes, [0 0], [0 app.MaxDistance], 'w-', 'LineWidth', 3, 'HitTest', 'off'); 
            text(app.ResponseAxes, 0, app.MaxDistance*1.05, 'Front', 'Color', 'w', ...
                'HorizontalAlignment', 'center', 'FontSize', 24, 'FontWeight', 'bold', 'HitTest', 'off');
            
            % (以下、Head表示ロジックは変更なし)
            ...
            if ~app.IsRotationMode
                headRad = app.DeadzoneRatio * 2;
                thHead = linspace(pi/2, 3*pi/2, 50);
                plot(app.ResponseAxes, headRad*cos(thHead), headRad*sin(thHead), 'w-', 'LineWidth', 1.5, 'HitTest', 'off');
                plot(app.ResponseAxes, [0 0], [headRad -headRad], 'w-', 'LineWidth', 1.5, 'HitTest', 'off');
                plot(app.ResponseAxes, 0, 0, 'o', 'MarkerEdgeColor', [0.8 0.8 0.8], 'MarkerFaceColor', [0.3 0.3 0.3], 'MarkerSize', 10, 'LineWidth', 3.0, 'HitTest', 'off'); 
                
                %{
                for d = app.GridDistances
                    for a = app.GridAngles
                        rad = deg2rad(a + 90);
                        plot(app.ResponseAxes, d*cos(rad), d*sin(rad), 'o', 'MarkerEdgeColor', [0.8 0.8 0.8], 'MarkerFaceColor', [0.3 0.3 0.3], 'MarkerSize', 10, 'LineWidth', 3.0, 'HitTest', 'off'); 
                    end
                end
                %}
                
            end
            hold(app.ResponseAxes, 'off');
            app.ResponseAxes.Visible = 'on';
        end

        
        % 回答処理
       
        function onAxesClick(app, ~, event)
    % クリックした座標の取得
    coords = event.IntersectionPoint;
    clickX = coords(1); 
    clickY = coords(2);
    
    % 距離 (r) の計算
    respDist = sqrt(clickX^2 + clickY^2);
    
    % 角度 (degree) の計算
    % MATLABのatan2dは右方向(X軸正)を0度として-180〜180度を返します。
    % このアプリの「Front=0度」は上方向(+Y軸)なので、90度分補正します。
    rawAng = atan2d(clickY, clickX) - 90;
    
    % 角度を -180 〜 180 の範囲に正規化 (必要に応じて 0〜360 に変更可)
    respAng = mod(rawAng + 180, 360) - 180;

    isHeadInternal = false;
    % デッドゾーン（頭の中）判定
    if respDist < app.DeadzoneRatio
        isHeadInternal = true;
        respDist = 0;
        respAng = 0;
        dx_m = 0; dy_m = 0;
    else
        % クリックした位置そのものをプロット座標にする
        dx_m = clickX; 
        dy_m = clickY;
    end

    % 被験者画面にクリック位置を赤丸で表示
    hold(app.ResponseAxes, 'on');
    plot(app.ResponseAxes, dx_m, dy_m, 'ro', 'MarkerSize', 15, 'LineWidth', 3, 'HitTest', 'off');
    hold(app.ResponseAxes, 'off');
    drawnow;

    % データの記録とモニター更新
    currentTrial = app.TrialList(app.CurrentTrialIdx);
    app.updateMonitorPlot(currentTrial.dist, currentTrial.angle, respDist, respAng, isHeadInternal);
    
    pause(0.3);
    app.recordData(respAng, respDist, isHeadInternal);
    app.nextTrial();
end

        function recordData(app, respAng, respDist, isHeadInternal)
            trial = app.TrialList(app.CurrentTrialIdx);
            angErr = mod((respAng - trial.angle) + 180, 360) - 180;
            distErr = respDist - trial.dist;
            isFrontTgt = (trial.angle <= 90 || trial.angle >= 270);
            isFrontRes = (respAng <= 90 || respAng >= 270);
            isConfused = (~isHeadInternal) && (isFrontTgt ~= isFrontRes);
            newRow = {app.CurrentTrialIdx, trial.condition, trial.dist, trial.angle, ...
                      respDist, respAng, distErr, angErr, isConfused, isHeadInternal};
            vNames = {'Trial', 'Condition', 'TargetDist', 'TargetAngle', ...
                      'RespDist', 'RespAngle', 'ErrDist', 'ErrAngle', 'FBConf', 'IsInsideHead'};
            newData = cell2table(newRow, 'VariableNames', vNames);
            if isempty(app.ExperimentLog), app.ExperimentLog = newData; else, app.ExperimentLog = [app.ExperimentLog; newData]; end
        end

        function finishExperiment(app)
            app.ResponseAxes.Visible = 'off';
            app.FixationText.Text = '終了'; app.FixationText.Visible = 'on';
            drawnow; pause(2.0);
            if ~exist(app.SaveDir, 'dir'), mkdir(app.SaveDir); end
            fname = sprintf('%s_%s.csv', app.SubjectName, datestr(now, 'yyyymmdd_HHMMSS'));
            writetable(app.ExperimentLog, fullfile(app.SaveDir, fname));
            app.log(['保存完了: ' fname]);
            app.onReset([],[]);
        end

        
        % モニター & その他
        
        function updateMonitorPlot(app, tgtDist, tgtAng, respDist, respAng, isHeadInternal)
            ax = app.MonitorAxes; cla(ax); hold(ax, 'on');
            theta = linspace(0, 2*pi, 100);
            for r = 0.5:0.5:app.MaxDistance
                plot(ax, r*cos(theta), r*sin(theta), ':', 'Color', [0.8 0.8 0.8]);
            end
            radT = deg2rad(tgtAng + 90);
            plot(ax, tgtDist*cos(radT), tgtDist*sin(radT), 'go', 'MarkerFaceColor', 'g');
            if isHeadInternal
                plot(ax, 0, 0, 'rx', 'MarkerSize', 15);
            else
                radR = deg2rad(respAng + 90);
                plot(ax, respDist*cos(radR), respDist*sin(radR), 'rx', 'LineWidth', 2);
            end
            hold(ax, 'off');
        end

        function onPlayTestTone(app, ~, ~)
            fs = 48000; t = 0:1/fs:2;
            y = 0.2 * sin(2*pi*1000*t).';
            playblocking(audioplayer([y, y], fs));
        end

        function onCloseApp(app, ~, ~)
            delete(app.SubjectFig); delete(app.ControlFig); delete(app);
        end

        function log(app, msg)
            if isvalid(app.LogTextArea)
                app.LogTextArea.Value = [app.LogTextArea.Value; {msg}];
                scroll(app.LogTextArea, 'bottom');
            end
            fprintf('%s\n', msg);
        end
    end
end
