// Copyright 2014 Toggl Desktop developers.

#ifndef SRC_UI_LINUX_TOGGLDESKTOP_TIMEENTRYEDITORWIDGET_H_
#define SRC_UI_LINUX_TOGGLDESKTOP_TIMEENTRYEDITORWIDGET_H_

#include <QWidget>
#include <QVector>
#include <QTimer>
#include <QListWidgetItem>
#include <QStackedWidget>

#include <stdint.h>
#include "./colorpicker.h"

namespace Ui {
class TimeEntryEditorWidget;
}

class AutocompleteView;
class AutocompleteListModel;
class GenericView;
class TimeEntryView;

class TimeEntryEditorWidget : public QWidget {
    Q_OBJECT

 public:
    explicit TimeEntryEditorWidget(QStackedWidget *parent = nullptr);
    ~TimeEntryEditorWidget();
    void setSelectedColor(QString color);

    void display();

 public slots:
    void deleteTimeEntry();
    void clickDone();

 private:
    Ui::TimeEntryEditorWidget *ui;

    QString guid;

    QVector<AutocompleteView *> timeEntryAutocompleteUpdate;
    bool timeEntryAutocompleteNeedsUpdate;

    QVector<AutocompleteView *> projectAutocompleteUpdate;
    bool projectAutocompleteNeedsUpdate;

    QVector<GenericView *> workspaceSelectUpdate;
    bool workspaceSelectNeedsUpdate;

    QVector<GenericView *> clientSelectUpdate;
    bool clientSelectNeedsUpdate;
    QString recentlyAddedClient;

    ColorPicker *colorPicker;

    QTimer *timer;

    int64_t duration;

    QString previousTagList;
    QSet<QString> recentlyAddedTags;

    TimeEntryView *timeEntry;

    AutocompleteListModel *descriptionModel;
    AutocompleteListModel *projectModel;

    bool applyNewProject();
    bool eventFilter(QObject *object, QEvent *event);
    void toggleNewClientMode(const bool visible);
    void toggleNewTagMode(bool visible);

 private slots:  // NOLINT
    void displayLogin(
        const bool open,
        const uint64_t user_id);

    void aboutToDisplayTimeEntryList();

    void displayTimeEntryEditor(
        const bool open,
        TimeEntryView *view,
        const QString focused_field_name);

    void displayTags(
        QVector<GenericView*> list);

    void displayWorkspaceSelect(
        QVector<GenericView *> list);

    void displayClientSelect(
        QVector<GenericView *> list);

    void displayTimeEntryAutocomplete(
        QVector<AutocompleteView *> list);

    void displayProjectAutocomplete(
        QVector<AutocompleteView *> list);

    void setProjectColors(QVector<QString> list);

    void timeout();

    void on_doneButton_clicked();
    void on_deleteButton_clicked();
    void on_addNewProject_clicked();
    void on_newProjectWorkspace_currentIndexChanged(int index);
    void on_description_activated(int index);
    void on_project_activated(int index);
    void on_duration_editingFinished();
    void on_start_editingFinished();
    void on_stop_editingFinished();
    void on_dateEdit_editingFinished();
    void on_billable_clicked(bool checked);
    void on_tags_itemClicked(QListWidgetItem *item);
    void on_addNewClient_clicked();
    void on_addClientButton_clicked();
    void on_cancelNewClient_clicked();
    void on_colorButton_clicked();
    void on_newTagButton_clicked();
    void on_newTag_returnPressed();
    void on_addNewTagButton_clicked();
};

#endif  // SRC_UI_LINUX_TOGGLDESKTOP_TIMEENTRYEDITORWIDGET_H_
