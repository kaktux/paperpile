Paperpile.PatternSettings = Ext.extend(Ext.Panel, {

  title: 'Location and Patterns Settings',

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      autoLoad: {
        url: Paperpile.Url('/screens/patterns'),
        callback: this.setupFields,
        scope: this
      },
      bodyStyle: 'pp-settings',
      iconCls: 'pp-icon-tools',
      autoScroll: true,
    });

    this.tooltips = {
      library_db: 'The database file that holds all your information of your Paperpile library',
      paper_root: 'The root folder where your PDFs and supplementary files are stored.',
      key_pattern: 'The pattern for the citation keys of your references (see help box).',
      pdf_pattern: 'The pattern to name your PDFs. Can include the citation key pattern <code>[key]</code> and slashes <code>/</code> to use subfolders.',
      attachment_pattern: 'The pattern for the folder where your supplementary files get stored. Can include the citation key pattern <code>[key]</code> and slashes <code>/</code> to use subfolders.'
    };

    Paperpile.PatternSettings.superclass.initComponent.call(this);

    this.isDirty = false;

  },

  //
  // Creates textfields, buttons and installs event handlers
  //
  setupFields: function() {

    this.textfields = {};

    Ext.get('patterns-cancel-button').on('click',
      function() {
        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
      });

    Ext.each(['library_db', 'paper_root', 'key_pattern', 'pdf_pattern', 'attachment_pattern'],
    function(item) {
      var field = new Ext.form.TextField({
        value: Paperpile.main.globalSettings[item],
        enableKeyEvents: true,
        width: 300,
      });

      field.on('keypress', function() {
        this.setSaveDisabled(false);
      },
      this);

      field.render(item + '_textfield', 0);

      new Ext.ToolTip({
        target: item + '_tooltip',
        minWidth: 50,
        maxWidth: 300,
        html: this.tooltips[item],
        anchor: 'left',
        showDelay: 0,
        hideDelay: 0
      });

      this.textfields[item] = field;

      if (item == 'library_db' || item == 'paper_root') {
        field.addClass('pp-textfield-with-button');
        var b = new Ext.Button({
          text: item == 'library_db' ? 'Choose file' : 'Choose folder',
          renderTo: item + '_button'
        });

        b.on('click', function() {
          var parts = Paperpile.utils.splitPath(this.textfields[item].getValue());
          new Paperpile.FileChooser({
            saveMode: item == 'library_db' ? true : false,
            selectionMode: item == 'library_db' ? 'FILE' : 'DIR',
            saveDefault: item == 'library_db' ? parts.file : '',
            currentRoot: parts.dir,
            warnOnExisting: false,
            callback: function(button, path) {
              if (button == 'OK') {
                this.textfields[item].setValue(path);
              }
            },
            scope: this
          }).show();
        },
        this);
      }

      if (item == 'key_pattern' || item == 'pdf_pattern' || item == 'attachment_pattern') {

        var task = new Ext.util.DelayedTask(this.updateFields, this);

        field.on('keydown', function() {
          this.isDirty = true;
          task.delay(500);
        },
        this);
      }

    },
    this);

    this.updateFields();

    this.setSaveDisabled(true);

  },

  //
  // Validates inputs and updates example fields
  //
  updateFields: function() {

    var params = {};

    Ext.each(['library_db', 'paper_root', 'key_pattern', 'pdf_pattern', 'attachment_pattern'],
    function(key) {
      params[key] = Ext.get(key + '_textfield').first().getValue();
    },
    this);

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/settings/pattern_example'),
      params: params,
      success: function(response) {
        var data = Ext.util.JSON.decode(response.responseText).data;

        var hasErrors = false;

        for (var f in data) {
          if (data[f].error) {
            this.textfields[f].markInvalid(data[f].error);
            Ext.get(f + '_example').update('');
            hasErrors = true;
          } else {
            Ext.get(f + '_example').update(data[f].string);
          }
        }

        if (this.isDirty) {
          this.setSaveDisabled(hasErrors);
        }
      },
      failure: Paperpile.main.onError,
      scope: this
    });

  },

  setSaveDisabled: function(disabled) {

    var button = Ext.get('patterns-save-button');

    button.un('click', this.submit, this);

    if (disabled) {
      button.replaceClass('pp-save-button', 'pp-save-button-disabled');
    } else {
      button.replaceClass('pp-save-button-disabled', 'pp-save-button');
      button.on('click', this.submit, this);
    }
  },

  submit: function() {

    var params = {};

    Ext.each(['library_db', 'paper_root', 'key_pattern', 'pdf_pattern', 'attachment_pattern'],
    function(item) {
      params[item] = this.textfields[item].getValue();
    },
    this);

    Paperpile.status.showBusy('Applying changes.');

    this.spot = new Ext.ux.Spotlight({
      animate: false,
    });

    this.spot.show('main-toolbar');

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/settings/update_patterns'),
      params: params,
      success: function(response) {
        this.spot.hide();
        var error = Ext.util.JSON.decode(response.responseText).error;
        if (error) {
          Paperpile.main.onError(response);
          return;
        }

        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
        var old_library_db = Paperpile.main.globalSettings.library_db;
        Paperpile.main.loadSettings(
          function() {
            // Complete reload only if database has
            // changed. This is not necessary if the
            // database has only be renamed but we
            // update also in this case.
            if (old_library_db != Paperpile.main.globalSettings.library_db) {
              Paperpile.main.tree.getRootNode().reload();
              Paperpile.main.tree.expandAll();

              // Note that this as async. Tags
              // should be loaded before results for
              // grid appear but it is not
              // guaranteed.
              Ext.StoreMgr.lookup('tag_store').reload();

              var tab;
              while (tab = Paperpile.main.tabs.items.first()) {
                Paperpile.main.tabs.remove(tab, true);
              }

              Paperpile.main.tabs.newDBtab('');
              Paperpile.main.tabs.setActiveTab(0);
              Paperpile.main.tabs.doLayout();
            } else {
              Paperpile.main.onUpdate({
                pub_delta: 1
              });
            }
            Paperpile.status.clearMsg();
          },
          this);
      },

      failure: function(response) {
        this.spot.hide();
        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab());
        Paperpile.main.loadSettings();
        Paperpile.main.onError(response);
      },
      scope: this
    });

  }

});