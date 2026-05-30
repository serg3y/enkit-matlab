function app = SimTab(tabGroup, app, cfg)
    H = cfg.H;
    ht = uitab(tabGroup, 'Title', 'Sim');
    
    uilabel(ht, 'Position', [10 H-60 200 30], 'Text', 'sim battery');
    uilabel(ht, 'Position', [10 H-100 200 30], 'Text', 'sim solar');
    uilabel(ht, 'Position', [10 H-140 200 30], 'Text', 'calc battery value');
    uilabel(ht, 'Position', [10 H-180 200 30], 'Text', 'calc solar value');
end