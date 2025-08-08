%% Preprocessing EEG-Rawfiles BA_Saume

% Verfasst von Thomas Saume, MSH Medical School Hamburg,
% thomas.saume@student.medichalschool-hamburg.de

% Das folgende Skript ist ein automatisiertes Preprocessing mittels EEGLAB & ERPLAB
% Ausgangssituation ist: Die Rohdaten jedes Versuchsdurchlaufs jedes Probanden
% wurden visuell gesichtet. Für jeden Trial wurden .set-Dateien erstellt
% (Prob1_a.set, Prob1_b.set...) Die .set-Dateien liegen jeweils probandenweise in
% einem Ordner. D.h.: Es gibt einen Ordner (rawfile_folder) in dem alle Sub-Ordner
% liegen. Diese Sub-Ordner sind nach dem Probandencode benannt (Prob1, Prob2...)
% In den Sub-Ordnern sind die .set-Dateien des jeweiligen Probanden
% Verwendete Erweiterungen: EEGLAB, ERPLAB, clean_rawdata, Picard, ICLabel

% Preprocessing Schritte:
% 1. Vorbereitung
% 2. Datensätze laden
% 3. Datensätze zusammenfügen
% 4. Datenbereinigung:
%    Referenzieren, Filtern, Artifact rejection, ICA, Interpolation
% 5. Eventlist einladen
% 6. Bins einladen
% 7. Segmentieren/Epochieren
% 8. Berechnung der ERPs
% 9. Filtern der ERPs
% 10. Clearen

%% 1. Vorbereitung
clearvars

eeglab nogui % EEGLAB starten

path_to_subjects = 'D:\path\to\rawfile_folder'; % Pfad zu den Subordnern 
cd(path_to_subjects);

output_folder = fullfile(path_to_subjects, 'output'); % Ordner für den Output
if ~isfolder(output_folder) % Wenn es diesen noch nicht gibt...
    mkdir(output_folder)    % wird er hier erstellt.
end

% list sei ein Array mit allen Probanden und ihren jeweiligen Ordnern
list = dir(fullfile(path_to_subjects, 'Prob*'));

% In der vorliegenden Studie gab es die Trials a bis k (Prob1_a, Prob1_b...)
trials = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k'}; 

% Pfad zur zuvor geschriebenen Binliste (für ERPLAB-Datenstruktur)
binlist_path = 'D:\path\to\Binliste.txt';

% Hier wird nun eine Tabelle erstellt, in der im Falle von Fehlern in der
% Vorverarbeitung die Probandencodes der betroffenen Probanden gesammelt werden,
% sodass im Anschluss überprüft werden kann, wo die Fehler zustande kamen
error_log = table('Size', [0, 1], 'VariableNames', {'Meldungen'}, 'VariableTypes', {'string'});

% In dieser Tabelle werden relevante Informationen zur interpolierten Kanälen
% und der ICA gesammelt. Die aufbereitete Tabelle ist dem Anhang der vorliegenden
% Bachelorarbeit zu entnehmen.
preprocessing_information_table = table('Size', [length(list), 3], 'VariableNames', {'Proband', 'Interpolation', 'Anzahl_ICs_rejected'}, 'VariableTypes', {'string', 'string', 'string'});

%% 2. Datensätze laden
% Die folgende Schleife lädt nun iterativ die Daten jedes Probanden und führt
% mit diesen alle folgenden Operationen  durch
for sub = 1:length(list)
    try
        subname = list(sub).name;
        preprocessing_information_table.Proband(sub) = subname;
        % Für den Überblick im Command Window:
        disp(repmat('*',1, 34))
        disp(['Es wird vorverarbeitet: ' subname '...'])
        disp(repmat('*',1, 34))
        
        % filepath sei der Pfad zum Subordner der aktuellen Iteration
        filepath = fullfile(path_to_subjects, list(sub).name); 
        cd(filepath)

        % In dieser Schleife werden alle Trials (a bis k) eines Probanden geladen
        for trial = 1:length(trials)
            filename = fullfile([subname, '_', trials{trial}, '.set']);
            EEG = pop_loadset('filename', filename ,'filepath', filepath);
            [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);
        end

        %% 3. Datensätze zusammenfügen
        % Alle zuvor geladenen Datensätze des Probanden werden nun zusammengefügt
        % ("merge/append datasets"), sodass die folgenden Operationen nur einmal
        % pro Proband durchgeführt werden müssen

        EEG = pop_mergeset(ALLEEG, [1:11], 0); % Datasets 1-11 = Trials a-k)

        setname = subname;
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname', setname, 'gui','off');

        % Für jedes Mal, wo pop_newset verwendet wird, gilt: es wäre auch möglich,
        % das Set mit dem Funktionsargument 'savenew' zu speichern, z.B. so:
        % savepath = fullfile(output_folder, [setname, '.set']);
        % [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 12,'setname', setname, 'savenew', savepath, 'gui','off');

        %% 4. Datenbereinigung
        % Re-Referenzieren, Filtern, Artifact rejection, ICA, Interpolation

        % Die Referenz die Messung der Spannung war im EEG die Elektrode Fcz.
        % Nun werden die Signale gegen das Mittel aller Elektroden re-referenziert
        EEG = pop_reref(EEG, []); % [] -> average reference
        setname = fullfile([subname, '_ref']);
        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname', setname ,'gui','off');

        % Um gleich noch nachzuvollziehen, welche Kanäle interpoliert wurden:
        alte_chanlocs = EEG.chanlocs; 
        alte_labels = {EEG.chanlocs.labels};

        % Signale unter 0.5Hz werden gedämpft
        EEG = pop_eegfiltnew(EEG,'locutoff', 0.5);

        % Artefakte werden über ASR erkannt und entfernt:
        EEG= clean_artifacts(EEG,'burst_crit',5,'line_crit',4,'chancorr_crit',.8);
        neue_labels = {EEG.chanlocs.labels};

        % Hier wird geschaut, ob Kanäle aussortiert wurden. Falls ja,
        % werden diese im preprocessing_information_table gespeichert
        int_channels = strjoin(setdiff(alte_labels, neue_labels), ' ');
        if ~isempty(int_channels)
            preprocessing_information_table.Interpolation(sub) = int_channels;
        end
        clear int_channels

        % Jetzt kommt eine Independent Component Analysis (ICA)
        EEG = pop_runica(EEG, 'picard'); % der Picard-Algorhitmus wird benutzt
        EEG = eeg_checkset(EEG, 'ica');
        % ICLabel klassifiziert ICs (funktioniert mit Machine Learning)
        EEG = pop_iclabel(EEG, 'default');

        % Wahrscheinlichste Klassen für ICs werden bestimmt
        [~,dom_klasse]=max(EEG.etc.ic_classification.ICLabel.classifications,[],2);
        dom_klasse_wkeit = zeros(length(dom_klasse),1);
        for IC_idx = 1:length(dom_klasse)
            dom_klasse_wkeit(IC_idx) = EEG.etc.ic_classification.ICLabel.classifications(IC_idx, dom_klasse(IC_idx));
        end
        n_ICs_original = height(EEG.icaweights); % Anzahl ICs pro Proband
        
        ICA_Schwelle = 0.5; % 50% als Schwelle (siehe unten)
        % "Gute" ICs sind diejenigen, die mit ICLabel zu mehr als 50% als 
        % "Brain" oder "Other" klassifiziert worden sind
        good_IC_idx = find((dom_klasse==1 & dom_klasse_wkeit>=ICA_Schwelle) | (dom_klasse==7 & dom_klasse_wkeit>=ICA_Schwelle));
        
        % Gute ICs werden beibehalten, schlechte verworfen.
        EEG = pop_subcomp(EEG, good_IC_idx, 0, 1);
        n_ICs_new = height(EEG.icaweights);

        % Nun soll noch dokumentiert werden, wie viele ICs rejected wurden.
        preprocessing_information_table.Anzahl_ICs_rejected(sub) =...
            n_ICs_original - n_ICs_new;

        % Zuvor mit clean_artifacts entfernte Kanäle werden sphärisch interpoliert
        EEG = pop_interp(EEG, alte_chanlocs, 'spherical');
        EEG = eeg_checkset(EEG);

        %% 5. Eventlist einladen
        % Ab hier beginnt nun die ERPLAB-Prozedur (nach Lopez-Calderon & Luck)
        EEG = pop_creabasiceventlist(EEG, 'AlphanumericCleaning', 'on', 'BoundaryNumeric', {-99}, 'BoundaryString', {'boundary'});

        setname = fullfile([subname, '_ref_elist']);
        [ALLEEG EEG CURRENTSET] = ...
            pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', setname, 'gui','off');

        %% 6. Bins einladen

        EEG = pop_binlister(EEG, 'BDF', binlist_path,...
            'IndexEL', 1, 'SendEL2', 'EEG', 'Voutput', 'EEG');

        setname = fullfile([subname, '_ref_elist_bins']);
        [ALLEEG EEG CURRENTSET] = ...
            pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', setname, 'gui','off');

        %% 7. Segmentieren/Epochieren
        % 200ms vor bis 600ms nach dem Target
        EEG = pop_epochbin(EEG, [-200.0  600.0], 'pre');

        setname = fullfile([subname, '_ref_elist_bins_be']);
        [ALLEEG EEG CURRENTSET] = ...
            pop_newset(ALLEEG, EEG, CURRENTSET,'setname', setname, 'gui','off');

        original_n_epochs = size(EEG.data, 3); % Anzahl der Epochen

        %% 8. Berechnung der ERPs

        ERP = pop_averager(EEG, 'Criterion', 'good', 'DQ_custom_wins', 0, 'DQ_flag',1,'DQ_preavg_txt',0,'ExcludeBoundary','on', 'SEM', 'on');

        erpfunction_erpname = fullfile([subname, '_erp']);
        erpfunction_filename = fullfile([subname, '_erp.erp']);
        ERP = pop_savemyerp(ERP, 'erpname', erpfunction_erpname, 'filename', erpfunction_filename, 'filepath', output_folder, 'Warning', 'on');

        %% 9. Filtern der ERPs
        % alles über 30Hz wird gefiltert
        ERP = pop_filterp(ERP, 1:32 , 'Cutoff', 30, 'Design', 'butter', 'Filter', 'lowpass', 'Order',  2);

        erpfunction_erpname = fullfile([subname, '_erp_filt']);
        erpfunction_filename = fullfile([subname, '_erp_filt.erp']);
        ERP = pop_savemyerp(ERP, 'erpname', erpfunction_erpname, 'filename', erpfunction_filename, 'filepath', output_folder, 'Warning', 'on');
        
    catch
        % Falls Fehler auftreten, werden diese hier abgefangen und dokumentiert
        error_log.Meldungen(end+1) = [subname ' konnte nicht vollständig vorverarbeitet werden!!!'];
    end
    % 
    %% 10. Clearen
    % Damit es in den nächsten Schleifeniterationen nicht zu Problemen
    % in den EEG-Strukturen bzw. -Variablen kommt
    STUDY = []; CURRENTSTUDY = 0; ALLEEG = [];
    EEG=[]; CURRENTSET=[]; ERP = []; ALLERP = [];

end

cd(output_folder)
% Es werden die interpolierten Kanäle und entfernten ICs als Excel gespeichert
information_table_filename = 'preprocessing_information.xlsx';
writetable(preprocessing_information_table, information_table_filename);

% Wenn es Fehler bei der Vorverarbeitung eines bestimmten Probanden gab,
% wird dies über den try-catch-Mechanismus in der Variable error_log gemeldet.
% Diese Variable wird letztlich im Command Window angezeigt. Dann ablesen,
% ob einzelne Probanden nicht verarbeitet werden konnten und Fehler beheben.
if isempty(error_log)
    disp(repmat('*',1,85))
    disp('Alle Probanden wurden vorverarbeitet und es gab keine Fehlermeldungen');
    disp(repmat('*',1,85))
else
    disp(repmat('*',1,64))
    disp(error_log);
    disp(repmat('*',1,64))
end
