#ifndef PDF_H
#define PDF_H

#include <QObject>
#include <QFile>
#include <poppler/qt4/poppler-qt4.h>

class PDF : public QObject {
  Q_OBJECT

 private:
  QString _file;
  Poppler::Document* document;

 public:
  PDF(QObject *parent = 0);
  QString getFile();
  void setFile(const QString & pdfFile);
  void openDocument();
  void closeDocument();
  QVariantMap info();
  QString text();
  QImage render(int page, float scale);
  QVariantMap wordList(int page);

};

#endif // PDF_H
