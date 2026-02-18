function mushra_interactive_improved()
    %% Script MUSHRA Interactif - Version Améliorée avec Menus Déroulants
    % Interface graphique claire avec filtrage par catégorie (S, P, G)
    
    clearvars -except data_raw; clc; close all;

    filename = 'mushra.csv';

    % --- 1. CHARGEMENT DES DONNÉES ---
    if ~isfile(filename)
        error('Fichier %s introuvable.', filename);
    end

    opts = detectImportOptions(filename);
    opts = setvaropts(opts, 'rating_stimulus', 'FillValue', '');
    try
        data_raw = readtable(filename, opts);
    catch
        data_raw = readtable(filename, 'Delimiter', ',');
    end
    
    % Nettoyage de base
    data_raw = data_raw(~contains(data_raw.trial_id, 'Entrainement', 'IgnoreCase', true), :);

    % --- 2. INTERFACE GRAPHIQUE AMÉLIORÉE ---
    hFig = figure('Name', 'MUSHRA Interactif - Interface Améliorée', ...
                  'Color', 'w', 'Position', [50 50 1600 950], ...
                  'WindowState', 'maximized');

    % Panneau de contrôle principal (plus haut)
    hPanel = uipanel('Parent', hFig, 'Position', [0 0.88 1 0.12], ...
                     'BackgroundColor', [0.95 0.95 0.97], 'BorderType', 'line');

    % --- LIGNE 1: Filtres de qualité ---
    y1 = 55;
    
    % Seuil Note Référence
    uicontrol('Parent', hPanel, 'Style', 'text', 'Position', [20 y1 160 20], ...
              'String', 'Seuil Note Référence (<):', 'HorizontalAlignment', 'right', ...
              'BackgroundColor', [0.95 0.95 0.97], 'FontSize', 10, 'FontWeight', 'bold');
    hEditScore = uicontrol('Parent', hPanel, 'Style', 'edit', 'Position', [190 y1 50 25], ...
                           'String', '90', 'FontSize', 10, 'BackgroundColor', 'w');

    % Nb Échecs
    uicontrol('Parent', hPanel, 'Style', 'text', 'Position', [260 y1 160 20], ...
              'String', 'Nb. Échecs Tolérés (≥):', 'HorizontalAlignment', 'right', ...
              'BackgroundColor', [0.95 0.95 0.97], 'FontSize', 10, 'FontWeight', 'bold');
    hEditCount = uicontrol('Parent', hPanel, 'Style', 'edit', 'Position', [430 y1 50 25], ...
                           'String', '2', 'FontSize', 10, 'BackgroundColor', 'w');

    % Bouton Mettre à jour
    uicontrol('Parent', hPanel, 'Style', 'pushbutton', 'Position', [510 y1-2 140 30], ...
              'String', 'Mettre à jour', 'FontSize', 10, 'FontWeight', 'bold', ...
              'BackgroundColor', [0.3 0.6 0.9], 'ForegroundColor', 'w', ...
              'Callback', @update_plots);

    % --- LIGNE 2: Filtres de visualisation ---
    y2 = 15;
    
    % Menu Type de musique
    uicontrol('Parent', hPanel, 'Style', 'text', 'Position', [20 y2 120 20], ...
              'String', 'Type de musique:', 'HorizontalAlignment', 'right', ...
              'BackgroundColor', [0.95 0.95 0.97], 'FontSize', 10, 'FontWeight', 'bold');
    hPopupMusic = uicontrol('Parent', hPanel, 'Style', 'popupmenu', ...
                            'Position', [150 y2 150 25], ...
                            'String', {'Tous', 'Sonate (S)', 'Prélude (P)', 'Gamme (G)'}, ...
                            'FontSize', 9, 'BackgroundColor', 'w', ...
                            'Callback', @update_plots);

    % Checkbox: Afficher REF
    hCheckRef = uicontrol('Parent', hPanel, 'Style', 'checkbox', ...
                          'Position', [320 y2 140 25], ...
                          'String', 'Afficher REF', 'Value', 1, ...
                          'BackgroundColor', [0.95 0.95 0.97], 'FontSize', 10, ...
                          'Callback', @update_plots);
          
    % Texte info (statistiques)
    hInfoText = uicontrol('Parent', hPanel, 'Style', 'text', ...
                          'Position', [680 y1 850 20], ...
                          'String', 'Initialisation...', 'HorizontalAlignment', 'left', ...
                          'BackgroundColor', [0.95 0.95 0.97], 'FontSize', 10, ...
                          'ForegroundColor', [0.1 0.4 0.7], 'FontWeight', 'bold');
                      
    % Texte info (filtres actifs)
    hFilterText = uicontrol('Parent', hPanel, 'Style', 'text', ...
                            'Position', [680 y2 850 20], ...
                            'String', '', 'HorizontalAlignment', 'left', ...
                            'BackgroundColor', [0.95 0.95 0.97], 'FontSize', 9, ...
                            'ForegroundColor', [0.4 0.4 0.4]);

    % Initialisation
    data_filtered = [];
    
    % Premier tracé
    update_plots();

    % --- 3. FONCTION DE MISE À JOUR ---
    function update_plots(~, ~)
        % Lecture paramètres
        seuil_ref = str2double(get(hEditScore, 'String'));
        max_fail = str2double(get(hEditCount, 'String'));
        
        if isnan(seuil_ref) || isnan(max_fail), return; end

        % -- FILTRAGE QUALITÉ --
        data_clean = data_raw; 
        sessions_a_supprimer = {};

        % A. Filtre Flat
        [G, sessions] = findgroups(data_clean.session_uuid);
        is_flat = splitapply(@(x) all(x == 50), data_clean.rating_score, G);
        if any(is_flat), sessions_a_supprimer = [sessions_a_supprimer; sessions(is_flat)]; end

        % B. Filtre Ref Dynamique
        is_ref = strcmpi(data_clean.rating_stimulus, 'reference');
        data_refs = data_clean(is_ref, :);
        nb_suppr_ref = 0;
        
        if ~isempty(data_refs)
            [G_ref, sessions_ref] = findgroups(data_refs.session_uuid);
            check_low = @(scores) sum(scores < seuil_ref);
            low_counts = splitapply(check_low, data_refs.rating_score, G_ref);
            
            bad_ref_s = sessions_ref(low_counts >= max_fail);
            if ~isempty(bad_ref_s)
                sessions_a_supprimer = [sessions_a_supprimer; bad_ref_s];
                nb_suppr_ref = length(bad_ref_s);
            end
        end

        sessions_a_supprimer = unique(sessions_a_supprimer);
        if ~isempty(sessions_a_supprimer)
            data_clean = data_clean(~ismember(data_clean.session_uuid, sessions_a_supprimer), :);
        end
        
        % Mise à jour texte info
        n_total = length(unique(data_raw.session_uuid));
        n_restant = length(unique(data_clean.session_uuid));
        set(hInfoText, 'String', sprintf('Participants: %d total | %d supprimés (dont %d pour REF) | %d restants', ...
            n_total, length(sessions_a_supprimer), nb_suppr_ref, n_restant));

        % -- PRÉPARATION CATÉGORIES --
        data_clean.Category = strings(height(data_clean), 1);
        data_clean.MainCategory = strings(height(data_clean), 1); % S, P, G
        
        for k = 1:height(data_clean)
            raw = char(data_clean.rating_stimulus{k});
            if strcmpi(raw, 'reference')
                data_clean.Category(k) = "REF";
                data_clean.MainCategory(k) = "REF";
            else
                data_clean.Category(k) = string(raw);
                % Extraire première lettre (S, P, ou G)
                if ~isempty(raw)
                    data_clean.MainCategory(k) = string(upper(raw(1)));
                end
            end
        end

        % -- APPLICATION FILTRES VISUALISATION --
        data_filtered = data_clean;
        show_ref = get(hCheckRef, 'Value');
        
        % Filtre Type de musique
        music_idx = get(hPopupMusic, 'Value');
        filter_info = '';
        
        switch music_idx
            case 2 % Sonate (S) - 3 pages: S_P1, S_P2, S_P3
                trials_to_keep = {'S_P1', 'S_P2', 'S_P3'};
                data_filtered = data_filtered(ismember(data_filtered.trial_id, trials_to_keep), :);
                filter_info = 'Type: Sonate (3 pages)';
            case 3 % Prélude (P) - 3 pages: P_P1, P_P2, P_P3
                trials_to_keep = {'P_P1', 'P_P2', 'P_P3'};
                data_filtered = data_filtered(ismember(data_filtered.trial_id, trials_to_keep), :);
                filter_info = 'Type: Prélude (3 pages)';
            case 4 % Gamme (G) - 1 page: G_P1
                trials_to_keep = {'G_P1'};
                data_filtered = data_filtered(ismember(data_filtered.trial_id, trials_to_keep), :);
                filter_info = 'Type: Gamme (1 page)';
            otherwise % Tous
                filter_info = 'Type: Tous (7 pages)';
        end
        
        % Filtrer REF si nécessaire
        if ~show_ref
            data_filtered = data_filtered(data_filtered.Category ~= "REF", :);
        end
        
        set(hFilterText, 'String', ['Filtres actifs: ' filter_info]);

        % -- DESSIN --
        delete(findobj(hFig, 'Type', 'axes'));
        
        if isempty(data_filtered)
            set(hFilterText, 'String', [get(hFilterText, 'String') ' | AUCUNE DONNÉE']);
            return;
        end
        
        unique_trials_filtered = unique(data_filtered.trial_id);
        n_trials = length(unique_trials_filtered);
        
        % Adaptation du layout selon le nombre de trials
        if n_trials == 1
            n_cols = 1; n_rows = 1;
        elseif n_trials == 2
            n_cols = 2; n_rows = 1;
        elseif n_trials == 3
            n_cols = 3; n_rows = 1;
        elseif n_trials <= 6
            n_cols = 3; n_rows = 2;
        else
            n_cols = 4; n_rows = 2;
        end
        
        show_ref = get(hCheckRef, 'Value');
        
        for i = 1:n_trials
            curr_trial = unique_trials_filtered{i};
            ax = subplot(n_rows, n_cols, i, 'Parent', hFig);
            hold(ax, 'on');
            
            page_data = data_filtered(strcmp(data_filtered.trial_id, curr_trial), :);
            if isempty(page_data), continue; end
            
            % Tri des catégories (REF à la fin si affiché)
            cats = unique(page_data.Category);
            
            if isempty(cats), continue; end
            
            idx_ref_cat = (cats == "REF");
            sorted_cats = [sort(cats(~idx_ref_cat)); cats(idx_ref_cat)];
            
            % Couleurs personnalisées
            colors = containers.Map();
            colors('REF') = [0.8 0.2 0.2]; % Rouge foncé
            
            % Boucle pour dessiner chaque boîte
            for j = 1:length(sorted_cats)
                this_cat = sorted_cats(j);
                scores = page_data.rating_score(page_data.Category == this_cat);
                
                if isempty(scores), continue; end
                scores = sort(scores);
                n = length(scores);
                
                % Statistiques
                q2 = median(scores);
                q1 = get_percentile_manual(scores, 25);
                q3 = get_percentile_manual(scores, 75);
                iqr_val = q3 - q1;
                
                % Moustaches
                w_high = min(max(scores), q3 + 1.5*iqr_val);
                w_low  = max(min(scores), q1 - 1.5*iqr_val);
                
                % Outliers
                outliers = scores(scores > w_high | scores < w_low);
                
                % -- DESSIN AMÉLIORÉ --
                x_pos = j;
                width = 0.6;
                
                % Couleur selon catégorie
                if this_cat == "REF"
                    box_color = colors('REF');
                    face_alpha = 0.3;
                else
                    box_color = [0.3 0.5 0.8]; % Bleu
                    face_alpha = 0.2;
                end
                
                % 1. Rectangle avec remplissage
                patch(ax, [x_pos - width/2, x_pos + width/2, x_pos + width/2, x_pos - width/2], ...
                      [q1, q1, q3, q3], box_color, 'EdgeColor', box_color, ...
                      'LineWidth', 1.5, 'FaceAlpha', face_alpha);
                
                % 2. Médiane (Ligne épaisse)
                plot(ax, [x_pos - width/2, x_pos + width/2], [q2, q2], ...
                     'Color', [0.8 0 0], 'LineWidth', 2.5);
                
                % 3. Moustaches
                plot(ax, [x_pos, x_pos], [q3, w_high], 'Color', box_color, 'LineWidth', 1.2);
                plot(ax, [x_pos - width/4, x_pos + width/4], [w_high, w_high], ...
                     'Color', box_color, 'LineWidth', 1.2);
                plot(ax, [x_pos, x_pos], [q1, w_low], 'Color', box_color, 'LineWidth', 1.2);
                plot(ax, [x_pos - width/4, x_pos + width/4], [w_low, w_low], ...
                     'Color', box_color, 'LineWidth', 1.2);
                
                % 4. Outliers
                if ~isempty(outliers)
                    plot(ax, repmat(x_pos, size(outliers)), outliers, 'o', ...
                         'MarkerEdgeColor', box_color, 'MarkerFaceColor', 'none', ...
                         'MarkerSize', 5, 'LineWidth', 1.2);
                end
                
                % 5. Afficher n
                text(ax, x_pos, 2, sprintf('n=%d', n), ...
                     'HorizontalAlignment', 'center', 'FontSize', 8, ...
                     'Color', [0.4 0.4 0.4]);
            end
            
            % Configuration Axes
            set(ax, 'XTick', 1:length(sorted_cats), 'XTickLabel', sorted_cats, ...
                'FontSize', 10, 'FontWeight', 'bold');
            xtickangle(ax, 45);
            ylabel(ax, 'Note MUSHRA', 'FontSize', 11, 'FontWeight', 'bold');
            ylim(ax, [0 105]);
            xlim(ax, [0.5 length(sorted_cats)+0.5]);
            grid(ax, 'on');
            set(ax, 'GridLineStyle', ':', 'GridAlpha', 0.3);
            title(ax, strrep(curr_trial, '_', ' '), 'Interpreter', 'none', ...
                  'FontSize', 12, 'FontWeight', 'bold');
            
            % Ligne Seuil
            yline(ax, seuil_ref, '--', 'LineWidth', 1.5, 'Alpha', 0.7, ...
                  'Color', [0.8 0.2 0.2], 'Label', sprintf('Seuil: %d', seuil_ref), ...
                  'LabelHorizontalAlignment', 'left', 'FontSize', 8);
            
            % Fond
            set(ax, 'Color', [0.98 0.98 0.99]);
        end
    end

    % Fonction locale pour calculer les percentiles
    function val = get_percentile_manual(data, p)
        n = length(data);
        pos = 1 + (n - 1) * p / 100;
        k = floor(pos);
        d = pos - k;
        if k == n
            val = data(n);
        else
            val = data(k) * (1 - d) + data(k + 1) * d;
        end
    end
end