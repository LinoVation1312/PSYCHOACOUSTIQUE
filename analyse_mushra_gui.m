function analyse_mushra_gui()
    % ANALYSE_MUSHRA_GUI
    % Interface interactive pour l'analyse des données MUSHRA
    % Mise à jour : Ajout du calcul de variance moyenne
    
    clear; clc; close all;
    % =====================================================================
    % 1. CHARGEMENT ET PRÉPARATION DES DONNÉES
    % =====================================================================
    filename = 'mushra.csv';
    
    if ~isfile(filename)
        errordlg(sprintf('Fichier "%s" introuvable.', filename), 'Erreur');
        return;
    end
    % Importation sécurisée
    opts = detectImportOptions(filename);
    opts = setvaropts(opts, 'rating_stimulus', 'FillValue', '');
    try
        raw_data = readtable(filename, opts);
    catch
        raw_data = readtable(filename, 'Delimiter', ',');
    end
    
    % Nettoyage initial : Suppression des entrainements
    raw_data = raw_data(~contains(raw_data.trial_id, 'Entrainement', 'IgnoreCase', true), :);
    
    % Conversion en string pour manipulation facile
    if iscell(raw_data.rating_stimulus)
        raw_data.rating_stimulus = string(raw_data.rating_stimulus);
    end
    if iscell(raw_data.trial_id)
        raw_data.trial_id = string(raw_data.trial_id);
    end
    if iscell(raw_data.session_uuid)
        raw_data.session_uuid = string(raw_data.session_uuid);
    end
    % =====================================================================
    % 2. CRÉATION DE L'INTERFACE (GUI)
    % =====================================================================
    
    % Fenêtre principale
    hFig = figure('Name', 'Analyse MUSHRA Interactive', ...
                  'Units', 'normalized', ...
                  'Position', [0.1, 0.1, 0.8, 0.8], ...
                  'Color', 'w');
    % --- PANNEAU DE CONTRÔLE (GAUCHE) ---
    pnlControls = uipanel(hFig, 'Position', [0 0 0.2 1], 'Title', 'Paramètres', 'BackgroundColor', 'w');
    % 1. Slider Seuil Référence
    uicontrol(pnlControls, 'Style', 'text', 'Position', [10 520 180 20], ...
              'String', 'Seuil Note Référence (<)', 'BackgroundColor', 'w', 'FontWeight', 'bold');
    lblTh = uicontrol(pnlControls, 'Style', 'text', 'Position', [10 500 180 20], ...
              'String', '90', 'BackgroundColor', 'w');
    sldTh = uicontrol(pnlControls, 'Style', 'slider', 'Position', [10 480 180 20], ...
              'Min', 0, 'Max', 100, 'Value', 90, 'SliderStep', [0.01 0.1], ...
              'Callback', @update_interface);
    % 2. Slider Max Erreurs
    uicontrol(pnlControls, 'Style', 'text', 'Position', [10 440 180 20], ...
              'String', 'Max Erreurs Tolérées', 'BackgroundColor', 'w', 'FontWeight', 'bold');
    lblErr = uicontrol(pnlControls, 'Style', 'text', 'Position', [10 420 180 20], ...
              'String', '2', 'BackgroundColor', 'w');
    sldErr = uicontrol(pnlControls, 'Style', 'slider', 'Position', [10 400 180 20], ...
              'Min', 0, 'Max', 10, 'Value', 2, 'SliderStep', [0.1 0.2], ...
              'Callback', @update_interface);
    % 3. Filtres Type (S / P / G)
    uicontrol(pnlControls, 'Style', 'text', 'Position', [10 340 180 20], ...
              'String', 'Filtrer par Type', 'BackgroundColor', 'w', 'FontWeight', 'bold');
    
    bgFilter = uibuttongroup(pnlControls, 'Position', [0.05 0.15 0.9 0.2], ...
                             'BorderType', 'none', 'BackgroundColor', 'w', ...
                             'SelectionChangedFcn', @update_interface);
    
    uicontrol(bgFilter, 'Style', 'radiobutton', 'String', 'Tout (Reset)', ...
              'Position', [10 130 150 20], 'Tag', 'Reset', 'BackgroundColor', 'w', 'Value', 1);
    uicontrol(bgFilter, 'Style', 'radiobutton', 'String', 'S (Sonate)', ...
              'Position', [10 100 150 20], 'Tag', 'S', 'BackgroundColor', 'w');
    uicontrol(bgFilter, 'Style', 'radiobutton', 'String', 'P (Prélude)', ...
              'Position', [10 70 150 20], 'Tag', 'P', 'BackgroundColor', 'w');
    uicontrol(bgFilter, 'Style', 'radiobutton', 'String', 'G (Gamme)', ...
              'Position', [10 40 150 20], 'Tag', 'G', 'BackgroundColor', 'w');
    % Info Participants
    lblInfo = uicontrol(pnlControls, 'Style', 'text', 'Position', [10 20 180 60], ...
              'String', 'N = ?', 'BackgroundColor', 'w', 'ForegroundColor', 'b');
    % --- ZONE DE GRAPHIQUE (DROITE) ---
    pnlPlot = uipanel(hFig, 'Position', [0.2 0 0.8 1], 'BackgroundColor', 'w', 'BorderType', 'none');
    
    % Initialisation
    update_interface();
    % =====================================================================
    % 3. FONCTIONS CALLBACK (LOGIQUE)
    % =====================================================================
    
    function update_interface(~, ~)
        % Récupération des paramètres
        thresh_val = round(get(sldTh, 'Value'));
        max_err_val = round(get(sldErr, 'Value'));
        
        % Mise à jour labels
        set(lblTh, 'String', num2str(thresh_val));
        set(lblErr, 'String', num2str(max_err_val));
        
        % Récupération du filtre trial selectionné
        selected_obj = get(bgFilter, 'SelectedObject');
        filter_tag = get(selected_obj, 'Tag');
        
        % 1. FILTRAGE DES PARTICIPANTS
        [clean_data, n_removed] = filter_participants(raw_data, thresh_val, max_err_val);
        
        % Mise à jour info texte
        n_total = length(unique(raw_data.session_uuid));
        n_kept = length(unique(clean_data.session_uuid));
        set(lblInfo, 'String', sprintf('Total: %d\nSupprimés: %d\nRestants: %d', ...
            n_total, n_removed, n_kept));
        % 2. FILTRAGE DES TRIALS (S, P, G)
        plot_data = clean_data;
        if strcmp(filter_tag, 'S')
            plot_data = plot_data(startsWith(plot_data.trial_id, 'S_', 'IgnoreCase', true), :);
        elseif strcmp(filter_tag, 'P')
            plot_data = plot_data(startsWith(plot_data.trial_id, 'P_', 'IgnoreCase', true), :);
        elseif strcmp(filter_tag, 'G')
            plot_data = plot_data(startsWith(plot_data.trial_id, 'G_', 'IgnoreCase', true), :);
        end
        
        % 3. DESSIN DES GRAPHIQUES
        draw_plots(pnlPlot, plot_data);
    end
    % --- Logique de filtrage ---
    function [df_out, n_rem] = filter_participants(df, th, max_err)
        sessions_a_supprimer = strings(0);
        
        [G, sessions] = findgroups(df.session_uuid);
        
        % Pour chaque session
        for i = 1:length(sessions)
            curr_sess = sessions(i);
            idx = (df.session_uuid == curr_sess);
            sub_df = df(idx, :);
            
            % A. Flatline (tout == 50)
            if all(sub_df.rating_score == 50)
                sessions_a_supprimer(end+1) = curr_sess;
                continue; 
            end
            
            % B. Référence cachée
            % On isole les lignes où c'est la ref
            is_ref = strcmpi(sub_df.rating_stimulus, 'reference');
            scores_ref = sub_df.rating_score(is_ref);
            
            if sum(scores_ref < th) >= max_err
                sessions_a_supprimer(end+1) = curr_sess;
            end
        end
        
        sessions_a_supprimer = unique(sessions_a_supprimer);
        n_rem = length(sessions_a_supprimer);
        
        if n_rem > 0
            df_out = df(~ismember(df.session_uuid, sessions_a_supprimer), :);
        else
            df_out = df;
        end
    end
    % --- Logique de dessin ---
    function draw_plots(parent_panel, data)
        % Nettoyer l'ancien contenu
        delete(allchild(parent_panel));
        
        unique_trials = unique(data.trial_id);
        n_trials = length(unique_trials);
        
        if n_trials == 0
            uicontrol(parent_panel, 'Style', 'text', 'String', 'Aucune donnée à afficher.', ...
                'FontSize', 14, 'Position', [100 300 400 50], 'BackgroundColor', 'w');
            return;
        end
        
        % Calcul grille
        n_cols = 3; 
        n_rows = ceil(n_trials / n_cols);
        
        for k = 1:n_trials
            curr_trial = unique_trials(k);
            
            % Création subplot
            ax = subplot(n_rows, n_cols, k, 'Parent', parent_panel);
            hold(ax, 'on');
            
            % Données du trial
            trial_rows = data(strcmp(data.trial_id, curr_trial), :);
            
            % Stats par stimulus
            [G_stim, stim_names] = findgroups(trial_rows.rating_stimulus);
            means = splitapply(@mean, trial_rows.rating_score, G_stim);
            stds = splitapply(@std, trial_rows.rating_score, G_stim);
            counts = splitapply(@numel, trial_rows.rating_score, G_stim);
            sems = stds ./ sqrt(counts);
            
            % --- AJOUT CALCUL VARIANCE ---
            variances = stds.^2;
            mean_variance = mean(variances, 'omitnan'); 
            
            % TRI : Alphabétique, Ref à la fin
            T = table(stim_names, means, sems);
            is_ref = strcmpi(T.stim_names, 'reference');
            
            T_others = sortrows(T(~is_ref, :), 'stim_names');
            T_ref = T(is_ref, :);
            T_final = [T_others; T_ref];
            
            % Plot
            x = 1:height(T_final);
            b = bar(ax, x, T_final.means);
            b.FaceColor = 'flat';
            b.EdgeColor = 'none';
            
            % Couleur (Bleu pour tout, Rouge pour Ref)
            b.CData = repmat([0.2 0.4 0.7], height(T_final), 1);
            if ~isempty(T_ref)
                b.CData(end, :) = [0.8 0.2 0.2];
            end
            
            % Barres erreur
            errorbar(ax, x, T_final.means, T_final.sems, 'k.', 'LineWidth', 1, 'CapSize', 6);
            
            % Esthétique
            set(ax, 'XTick', x, 'XTickLabel', T_final.stim_names);
            xtickangle(ax, 45);
            ylim(ax, [0 105]);
            grid(ax, 'on');
            title(ax, curr_trial, 'Interpreter', 'none');
            
            % Afficher N et Variance Moyenne
            n_sujets = length(unique(trial_rows.session_uuid));
            
            % --- MISE A JOUR DU TEXTE ---
            info_str = sprintf('N=%d\nVar. Moy: %.1f', n_sujets, mean_variance);
            
            text(ax, 0.05, 0.95, info_str, 'Units', 'normalized', ...
                'BackgroundColor', 'w', 'EdgeColor', 'k', 'VerticalAlignment', 'top');
            
            hold(ax, 'off');
        end
    end
end