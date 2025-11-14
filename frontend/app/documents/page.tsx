'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { Document } from '@/lib/types';
import styles from './documents.module.scss';

export default function DocumentsPage() {
  const [documents, setDocuments] = useState<Document[]>([]);
  const [loading, setLoading] = useState(true);
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [documentType, setDocumentType] = useState('');

  useEffect(() => {
    loadDocuments();
  }, []);

  const loadDocuments = async () => {
    try {
      const res = await api.get('/document');
      // Yii2 REST может возвращать данные в разных форматах
      const docs = Array.isArray(res.data) ? res.data : (res.data?.items || []);
      setDocuments(docs);
    } catch (error) {
      console.error('Error loading documents:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedFile(file);
    }
  };

  const handleUpload = async () => {
    if (!selectedFile || !documentType) {
      alert('Пожалуйста, выберите файл и укажите тип документа');
      return;
    }

    setUploading(true);
    try {
      const formData = new FormData();
      formData.append('file', selectedFile);
      formData.append('type', documentType);

      await api.post('/document/upload', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });

      // Закрываем модальное окно и сбрасываем форму
      setShowUploadModal(false);
      setSelectedFile(null);
      setDocumentType('');
      
      // Обновляем список документов
      await loadDocuments();
      
      alert('Документ успешно загружен');
    } catch (error: any) {
      console.error('Error uploading document:', error);
      alert(error.response?.data?.error || 'Ошибка при загрузке документа');
    } finally {
      setUploading(false);
    }
  };

  const handleDownload = async (doc: Document) => {
    try {
      // Скачивание через axios с responseType: 'blob'
      const response = await api.get(`/document/${doc.id}/download`, {
        responseType: 'blob',
      });

      // Получаем имя файла из file_path (последний сегмент)
      let filename = doc.file_path.split('/').pop() || 'document';
      
      // Убираем префикс uniqid если он есть (для старых файлов)
      const uniqidMatch = filename.match(/^[a-f0-9]+(?:\.[0-9]+)?_(.+)$/i);
      if (uniqidMatch) {
        filename = uniqidMatch[1];
      }

      // Создаём blob URL
      const url = URL.createObjectURL(response.data);
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      
      // Очистка
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (error: any) {
      console.error('Error downloading document:', error);
      
      let errorMessage = 'Ошибка при скачивании файла';
      
      if (error.response) {
        const status = error.response.status;
        if (status === 403) {
          errorMessage = 'Доступ запрещен. У вас нет прав для скачивания этого документа.';
        } else if (status === 404) {
          errorMessage = 'Файл не найден на сервере.';
        } else if (status === 401) {
          errorMessage = 'Требуется авторизация. Пожалуйста, войдите в систему.';
        } else {
          errorMessage = `Ошибка сервера (${status}). Попробуйте позже.`;
        }
      } else if (error.request) {
        errorMessage = 'Не удалось подключиться к серверу. Проверьте подключение к интернету.';
      }
      
      alert(errorMessage);
    }
  };

  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'pending':
        return 'На проверке';
      case 'approved':
        return 'Одобрен';
      case 'rejected':
        return 'Отклонён';
      default:
        return status;
    }
  };

  const getStatusClass = (status: string) => {
    switch (status) {
      case 'pending':
        return styles.statusPending;
      case 'approved':
        return styles.statusApproved;
      case 'rejected':
        return styles.statusRejected;
      default:
        return '';
    }
  };

  if (loading) {
    return <div className={styles.loading}>Загрузка...</div>;
  }

  return (
    <div className={styles.documents}>
      <header className={styles.header}>
        <div className={styles.headerContent}>
          <h1>Хранилище документов</h1>
          <button
            onClick={() => setShowUploadModal(true)}
            className={styles.uploadButton}
          >
            Загрузить документ
          </button>
        </div>
      </header>

      <main className={styles.content}>
        {documents.length === 0 ? (
          <div className={styles.empty}>Нет документов</div>
        ) : (
          <div className={styles.documentsList}>
            {documents.map((doc) => (
              <div key={doc.id} className={styles.documentCard}>
                <div className={styles.documentInfo}>
                  <h3>{doc.file_path.split('/').pop()}</h3>
                  <p className={styles.documentType}>Тип: {doc.type || 'Не указан'}</p>
                  <span className={`${styles.statusBadge} ${getStatusClass(doc.status)}`}>
                    {getStatusLabel(doc.status)}
                  </span>
                </div>
                <button
                  onClick={() => handleDownload(doc)}
                  className={styles.downloadButton}
                >
                  Скачать
                </button>
              </div>
            ))}
          </div>
        )}
      </main>

      {/* Модальное окно загрузки */}
      {showUploadModal && (
        <div className={styles.modalOverlay} onClick={() => !uploading && setShowUploadModal(false)}>
          <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
            <div className={styles.modalHeader}>
              <h2>Загрузить документ</h2>
              <button
                className={styles.modalClose}
                onClick={() => !uploading && setShowUploadModal(false)}
                disabled={uploading}
              >
                ×
              </button>
            </div>
            <div className={styles.modalBody}>
              <div className={styles.formGroup}>
                <label htmlFor="file">Файл</label>
                <input
                  id="file"
                  type="file"
                  onChange={handleFileSelect}
                  disabled={uploading}
                  accept=".pdf,.docx,.xlsx,.doc,.xls,.jpg,.jpeg,.png,.txt"
                />
                {selectedFile && (
                  <p className={styles.fileName}>{selectedFile.name}</p>
                )}
              </div>
              <div className={styles.formGroup}>
                <label htmlFor="type">Тип документа</label>
                <select
                  id="type"
                  value={documentType}
                  onChange={(e) => setDocumentType(e.target.value)}
                  disabled={uploading}
                >
                  <option value="">Выберите тип</option>
                  <option value="Паспорт отходов">Паспорт отходов</option>
                  <option value="Журнал учета отходов">Журнал учета отходов</option>
                  <option value="Инвентаризация">Инвентаризация</option>
                  <option value="План НМУ">План НМУ</option>
                  <option value="2-ТП (воздух)">2-ТП (воздух)</option>
                  <option value="Другое">Другое</option>
                </select>
              </div>
            </div>
            <div className={styles.modalFooter}>
              <button
                className={styles.cancelButton}
                onClick={() => !uploading && setShowUploadModal(false)}
                disabled={uploading}
              >
                Отмена
              </button>
              <button
                className={styles.submitButton}
                onClick={handleUpload}
                disabled={uploading || !selectedFile || !documentType}
              >
                {uploading ? 'Загрузка...' : 'Загрузить'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
