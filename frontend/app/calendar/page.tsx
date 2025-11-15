'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { Event } from '@/lib/types';
import styles from './calendar.module.scss';

const EventModal = ({ event, onClose, onSave }: { event: Event | null, onClose: () => void, onSave: (data: any) => void }) => {
  const [title, setTitle] = useState(event?.title || '');
  const [date, setDate] = useState(event?.date ? (event.date.includes('T') ? event.date.split('T')[0] : event.date) : '');
  const [completed, setCompleted] = useState(event?.completed || false);

  useEffect(() => {
    setTitle(event?.title || '');
    setDate(event?.date ? (event.date.includes('T') ? event.date.split('T')[0] : event.date) : '');
    setCompleted(event?.completed || false);
  }, [event]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !date) {
      alert('Заполните все обязательные поля');
      return;
    }
    onSave({ title, date, completed });
  };

  return (
    <div className={styles.modalOverlay} onClick={onClose}>
      <div className={styles.modal} onClick={(e) => e.stopPropagation()}>
        <h2>{event ? 'Редактировать событие' : 'Добавить событие'}</h2>
        <form onSubmit={handleSubmit}>
          <div className={styles.formGroup}>
            <label>Название события *</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
          </div>
          <div className={styles.formGroup}>
            <label>Дата *</label>
            <input
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              required
            />
          </div>
          <div className={styles.formGroup}>
            <label>
              <input
                type="checkbox"
                checked={completed}
                onChange={(e) => setCompleted(e.target.checked)}
              />
              Выполнено
            </label>
          </div>
          <div className={styles.modalActions}>
            <button type="button" onClick={onClose}>Отмена</button>
            <button type="submit">Сохранить</button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default function CalendarPage() {
  const [events, setEvents] = useState<Event[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [showEventModal, setShowEventModal] = useState(false);
  const [editingEvent, setEditingEvent] = useState<Event | null>(null);
  const [client, setClient] = useState<any>(null);

  useEffect(() => {
    loadCurrentUser();
    loadClient();
    loadEvents();
  }, []);

  const loadCurrentUser = async () => {
    try {
      const res = await api.get('/auth/me');
      setCurrentUser(res.data);
    } catch (error) {
      console.error('Error loading current user:', error);
      setCurrentUser(null);
    }
  };

  const loadClient = async () => {
    try {
      const res = await api.get('/client');
      const clients = Array.isArray(res.data) ? res.data : (res.data?.items || []);
      if (clients.length > 0) {
        setClient(clients[0]);
      }
    } catch (error) {
      console.error('Error loading client:', error);
    }
  };

  const loadEvents = async () => {
    try {
      const res = await api.get('/event');
      // Yii2 REST может возвращать данные в разных форматах
      let evts = Array.isArray(res.data) ? res.data : (res.data?.items || []);
      
      // Удаляем дубликаты событий по ID и комбинации title+date
      const seenEventIds = new Set<number>();
      const seenEventKeys = new Set<string>();
      evts = evts.filter((evt: Event) => {
        // Проверка по ID
        if (seenEventIds.has(evt.id)) return false;
        // Проверка по комбинации title+date
        const key = `${evt.title}-${evt.date}`;
        if (seenEventKeys.has(key)) return false;
        seenEventIds.add(evt.id);
        seenEventKeys.add(key);
        return true;
      });
      
      setEvents(evts);
    } catch (error) {
      console.error('Error loading events:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteEvent = async (eventId: number) => {
    if (!confirm('Удалить это событие?')) return;
    try {
      await api.delete(`/event/${eventId}`);
      setEvents(events.filter(e => e.id !== eventId));
    } catch (error) {
      console.error('Error deleting event:', error);
      alert('Ошибка при удалении события');
    }
  };

  const handleSaveEvent = async (eventData: any) => {
    try {
      if (!client?.id) {
        alert('Клиент не найден');
        return;
      }

      const payload = {
        title: eventData.title,
        date: eventData.date,
        completed: eventData.completed || false,
        client_id: client.id,
      };

      if (editingEvent) {
        await api.patch(`/event/${editingEvent.id}`, payload);
      } else {
        await api.post('/event', payload);
      }
      
      await loadEvents();
      setShowEventModal(false);
      setEditingEvent(null);
    } catch (error: any) {
      console.error('Error saving event:', error);
      const errorMsg = error.response?.data?.message || error.response?.data?.error || 'Ошибка при сохранении события';
      alert(errorMsg);
    }
  };

  if (loading) {
    return <div className={styles.loading}>Загрузка...</div>;
  }

  const sortedEvents = [...events].sort((a, b) => 
    new Date(a.date).getTime() - new Date(b.date).getTime()
  );

  const upcomingEvents = sortedEvents.filter((e) => !e.completed && new Date(e.date) >= new Date());
  const pastEvents = sortedEvents.filter((e) => e.completed || new Date(e.date) < new Date());
  const isAdmin = currentUser?.role === 'admin';

  return (
    <div className={styles.calendar}>
      <header className={styles.header}>
        <h1>Календарь отчётности</h1>
      </header>

      <main className={styles.content}>
        {isAdmin && (
          <div style={{ marginBottom: '1.5rem', display: 'flex', justifyContent: 'flex-end' }}>
            <button
              onClick={() => {
                setEditingEvent(null);
                setShowEventModal(true);
              }}
              className={styles.addButton}
            >
              + Добавить событие
            </button>
          </div>
        )}
        
        <div className={styles.section}>
          <h2>Предстоящие события</h2>
          {upcomingEvents.length === 0 ? (
            <div className={styles.empty}>Нет предстоящих событий</div>
          ) : (
            <div className={styles.eventsList}>
              {upcomingEvents.map((event) => (
                <div key={event.id} className={styles.eventCard}>
                  <div className={styles.eventDate}>
                    {new Date(event.date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })}
                  </div>
                  <div className={styles.eventTitle}>{event.title}</div>
                  {isAdmin && (
                    <div style={{ display: 'flex', gap: '0.5rem' }}>
                      <button
                        onClick={() => {
                          setEditingEvent(event);
                          setShowEventModal(true);
                        }}
                        className={styles.editButton}
                      >
                        Редактировать
                      </button>
                      <button
                        onClick={() => handleDeleteEvent(event.id)}
                        className={styles.deleteButton}
                      >
                        Удалить
                      </button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        <div className={styles.section}>
          <h2>Прошедшие события</h2>
          {pastEvents.length === 0 ? (
            <div className={styles.empty}>Нет прошедших событий</div>
          ) : (
            <div className={styles.eventsList}>
              {pastEvents.map((event) => (
                <div key={event.id} className={`${styles.eventCard} ${styles.past}`}>
                  <div className={styles.eventDate}>
                    {new Date(event.date).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })}
                  </div>
                  <div className={styles.eventTitle}>{event.title}</div>
                  {event.completed && (
                    <span className={styles.completedBadge}>Выполнено</span>
                  )}
                  {isAdmin && (
                    <div style={{ display: 'flex', gap: '0.5rem' }}>
                      <button
                        onClick={() => {
                          setEditingEvent(event);
                          setShowEventModal(true);
                        }}
                        className={styles.editButton}
                      >
                        Редактировать
                      </button>
                      <button
                        onClick={() => handleDeleteEvent(event.id)}
                        className={styles.deleteButton}
                      >
                        Удалить
                      </button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
        
        {showEventModal && (
          <EventModal
            event={editingEvent}
            onClose={() => {
              setShowEventModal(false);
              setEditingEvent(null);
            }}
            onSave={handleSaveEvent}
          />
        )}
      </main>
    </div>
  );
}

