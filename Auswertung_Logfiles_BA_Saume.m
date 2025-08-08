%% Auswertung Logfiles BA_Saume

% Verfasst von Thomas Saume, MSH Medical School Hamburg,
% thomas.saume@student.medichalschool-hamburg.de

% In diesem Skript werden die mit Presentation gespeicherten Logfiles geladen
% und verarbeite. Resultat sind Reaktionszeiten und Tefferquoten jedes Probanden
% Es wird die selbsterstellte Funktion readlogfile verwendet, die über das
% Import-Data-Tool von MATLAB erstellt werden kann.

clearvars
% Ordner mit allen Logfiles drin (und mit der Funktion readlogfile)
logfile_folder = 'F:\path\to\logfiles';
cd(logfile_folder)

data_lines = [6, 120]; % Angabe welche Zeilen des Logfiles importiert werden sollen
% Das erste Logfile des Probanden wird einzeln geladen, die danach werden iterativ
% hinzugefügt, deshalb ein Array mit allen Durchgängen außer Durchgang a
trials_left = {'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k'}; 
% Bedingungen des Experiments:
conditions = {'self_con_hapemoji', 'self_inc_angemoji', 'self_inc_hapemoji',...
    'self_con_angemoji', 'other_con_hapemoji', 'other_inc_angemoji',...
    'other_inc_hapemoji', 'other_con_angemoji'};

% 8 Bedingungen für Trefferquoten (hr) + 8 Bedingungen für Reaktionszeiten (rt)
number_numeric_entries = 16;
% Im Folgenden soll nun die Variable "variable_names" erstellt werden mit
% jeweils hitrate (hr) und reaction time (rt) für jede Bedingung. 
prefixes = {'hr_', 'rt_'};
variable_names = {'Subject'}; % Start mit 'Subject'
for i = 1:length(prefixes) % Vor jede Bedingung einmal jeweils 'hr' und 'rt'
    for j = 1:length(conditions)
        variable_names{end+1} = [prefixes{i}, conditions{j}];
    end
end

% Diese Tabelle soll am Ende die Reaktionszeiten und Trefferquoten aller
% Probanden in allen Bedingungen beinhalten und als Excel-Datei gespeichert werden
% 36 Zeilen für 36 Probanden
final_table = table('Size', [36, number_numeric_entries+1],...
    'VariableTypes', ['string', repmat({'double'}, 1, number_numeric_entries)],...
    'VariableNames', variable_names);

% Diese Schleife lädt iterativ die Daten jedes Probanden und wertet diese aus
for sub = 1:height(final_table)
    subname = sprintf('Prob%d', sub); % Probandencode
    final_table.Subject(sub) = subname; % Probandencode in die Tabelle füllen

    % Erstes Logfile des Probanden:
    filename = fullfile([subname, '_a-EEG_PersonalAffectEmoji_sce_1_black.log']);
    subject_data = readlogfile(filename, data_lines);

    % Nun werden alle Logfiles aneinandergefügt, sodass die Auswertung nicht für
    % jedes Logfile einzeln erfolgen muss, sondern probandenweise
    for trial = 1:length(trials_left)
        filename = fullfile([subname, '_', trials_left{trial}, '-EEG_PersonalAffectEmoji_sce_', num2str(trial+1), '_black.log']);
        logfile_to_be_added = readlogfile(filename, data_lines);
        % Mit vertcat(a, b) wird Tabelle b unten an Tabelle a rangehängt
        subject_data = vertcat(subject_data, logfile_to_be_added);
        clear logfile_to_be_added
    end

    % Vorkehrungen für die Berechnung der Trefferquoten und Reaktionszeiten:

    % Zeilen (Indizes) des Datensatzes in denen die Bedingungen jeweils vorkamen:
    % Die ersten zwei Triggercodes sind immer die für einen linksseitigen
    % Reiz, die letzten beiden für einen rechtsseitigen
    idx_self_con_hapemoji = find(subject_data.Code=="11" | subject_data.Code=="21" | subject_data.Code=="12" | subject_data.Code=="22");
    idx_self_inc_angemoji = find(subject_data.Code=="13" | subject_data.Code=="23" | subject_data.Code=="14" | subject_data.Code=="24");
    idx_self_inc_hapemoji = find(subject_data.Code=="31" | subject_data.Code=="41" | subject_data.Code=="32" | subject_data.Code=="42");
    idx_self_con_angemoji = find(subject_data.Code=="33" | subject_data.Code=="43" | subject_data.Code=="34" | subject_data.Code=="44");
    idx_other_con_hapemoji = find(subject_data.Code=="51" | subject_data.Code=="61" | subject_data.Code=="52" | subject_data.Code=="62");
    idx_other_inc_angemoji = find(subject_data.Code=="53" | subject_data.Code=="63" | subject_data.Code=="54" | subject_data.Code=="64");
    idx_other_inc_hapemoji = find(subject_data.Code=="71" | subject_data.Code=="81" | subject_data.Code=="72" | subject_data.Code=="82");
    idx_other_con_angemoji = find(subject_data.Code=="73" | subject_data.Code=="83" | subject_data.Code=="74" | subject_data.Code=="84");

    % Anzahl wie häufig die Bedingungen vorkamen (sollte identisch sein):
    n_self_con_hapemoji = length(idx_self_con_hapemoji);
    n_self_inc_angemoji = length(idx_self_inc_angemoji);
    n_self_inc_hapemoji = length(idx_self_inc_hapemoji);
    n_self_con_angemoji = length(idx_self_con_angemoji);
    n_other_con_hapemoji = length(idx_other_con_hapemoji);
    n_other_inc_angemoji = length(idx_other_inc_angemoji);
    n_other_inc_hapemoji = length(idx_other_inc_hapemoji);
    n_other_con_angemoji = length(idx_other_con_angemoji);

    % Die Schleife iteriert über alle Conditions
    for cond = 1:length(conditions)
        condition = conditions{cond};

        % Wenn es ein Happy Trial war, gilt die obere Pfeiltaste als eine richtige
        % Antwort, Triggercode 201. Wenn es ein Angry Trial war, gilt die untere
        % Pfeiltaste eine richtige Antwort, Triggercode 202.
        if contains(condition, 'hap')
            correct_code = "201";
        elseif contains(condition, 'ang')
            correct_code = "202";
        end
        
        % Wie oben definiert...
        %...das ist die Indexvariable der Conditon der aktuellen Iteration
        idx_var = eval(['idx_' condition]);
        %...das ist die n-Variable der aktuellen Condition der aktuellen Iteration
        n_trials = eval(['n_' condition]); 

        % Rechnung:
        corr = 0;
        rts = [];
        for idx = 1:length(idx_var)
            % Wenn die Antwort des Probanden richtig war, rechne ihm ein "Korrekt"
            % an und berechne die Reaktionszeit des Trials
            if subject_data.Code(idx_var(idx)+1) == correct_code 
                corr = corr + 1; %...rechne ...
                rts(end+1) = subject_data.Time(idx_var(idx)+1) - subject_data.Time(idx_var(idx));
            end
        end
        hitrate = corr / n_trials; %Trefferquote
        mean_rt = mean(rts) / 10; % Durchschnittliche Reaktionszeit
        % Ergebnisse in final_table eintragen
        final_table.(['hr_' condition])(sub) = hitrate;
        final_table.(['rt_' condition])(sub) = mean_rt;
    end
    clear subject_data
end

% Excel-File der Trefferquoten und Reaktionszeiten speichern
excel_filename = fullfile(logfile_folder, 'VerhaltensdatenAuswertung.xlsx');
writetable(final_table, excel_filename);
