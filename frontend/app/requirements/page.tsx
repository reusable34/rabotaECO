'use client';

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import api from '@/lib/api';
import { Requirement, Client, Category, Document, Contract, Event, Risk } from '@/lib/types';
import styles from './requirements.module.scss';

type TabType = 'requirements' | 'artifacts' | 'calendar' | 'risks' | 'legislation' | 'contracts' | 'costs' | 'templates';

export default function RequirementsPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [activeTab, setActiveTab] = useState<TabType>('requirements');
  const [requirements, setRequirements] = useState<Requirement[]>([]);
  const [client, setClient] = useState<Client | null>(null);
  const [categories, setCategories] = useState<Category[]>([]);
  const [documents, setDocuments] = useState<Document[]>([]);
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [events, setEvents] = useState<Event[]>([]);
  const [risks, setRisks] = useState<Record<number, Risk[]>>({});
  const [loading, setLoading] = useState(true);
  const [recalculating, setRecalculating] = useState(false);
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [showEventModal, setShowEventModal] = useState(false);
  const [editingEvent, setEditingEvent] = useState<Event | null>(null);

  // Фильтры
  const [categoryId, setCategoryId] = useState<number | ''>('');
  const [hasWell, setHasWell] = useState<boolean | ''>('');
  const [hasRiver, setHasRiver] = useState<boolean | ''>('');
  const [hasByproduct, setHasByproduct] = useState<boolean | ''>('');
  const [responsiblePerson, setResponsiblePerson] = useState('');

  useEffect(() => {
    loadData();
    loadCurrentUser();
  }, []);

  const loadCurrentUser = async () => {
    try {
      const res = await api.get('/auth/me');
      setCurrentUser(res.data);
      console.log('Current user loaded:', res.data);
    } catch (error) {
      console.error('Error loading current user:', error);
      setCurrentUser(null);
    }
  };

  const loadData = async () => {
    try {
      // Проверяем, есть ли client_id в URL (для просмотра из админ-панели)
      const clientIdFromUrl = searchParams?.get('client_id');
      const requirementUrl = clientIdFromUrl ? `/requirement?client_id=${clientIdFromUrl}` : '/requirement';
      
      const [clientRes, requirementsRes, categoriesRes, documentsRes, contractsRes, eventsRes] = await Promise.all([
        clientIdFromUrl ? api.get(`/client/${clientIdFromUrl}`).then(res => ({ data: [res.data] })) : api.get('/client'),
        api.get(requirementUrl),
        api.get('/category'),
        api.get('/document'),
        api.get('/contract'),
        api.get('/event'),
      ]);

      const clients = Array.isArray(clientRes.data) ? clientRes.data : (clientRes.data?.items || []);
      let reqs = Array.isArray(requirementsRes.data) ? requirementsRes.data : (requirementsRes.data?.items || []);
      
      console.log('🔍 DEBUG (начальная загрузка): Полный ответ API:', JSON.stringify(requirementsRes.data, null, 2));
      console.log('🔍 DEBUG (начальная загрузка): Требования получены с бэкенда:', reqs.length, 'шт.');
      console.log('🔍 DEBUG (начальная загрузка): URL запроса:', requirementUrl);
      console.log('🔍 DEBUG (начальная загрузка): Тип данных:', Array.isArray(requirementsRes.data) ? 'массив' : 'объект');
      if (!Array.isArray(requirementsRes.data) && requirementsRes.data?.items) {
        console.log('🔍 DEBUG (начальная загрузка): Используется items, всего элементов:', requirementsRes.data.items.length);
      }
      console.log('🔍 DEBUG (начальная загрузка): Все требования:', reqs.map((r: Requirement) => ({ id: r.id, title: r.title })));
      
      // Удаляем дубликаты по ID и названию
      const seenIds = new Set<number>();
      const seenTitles = new Set<string>();
      const beforeFilterCount = reqs.length;
      reqs = reqs.filter((req: Requirement) => {
        if (seenIds.has(req.id)) {
          console.warn('⚠️ Дубликат по ID (начальная загрузка):', req.id, req.title);
          return false;
        }
        if (seenTitles.has(req.title)) {
          console.warn('⚠️ Дубликат по названию (начальная загрузка):', req.title);
          return false;
        }
        seenIds.add(req.id);
        seenTitles.add(req.title);
        return true;
      });
      
      if (beforeFilterCount !== reqs.length) {
        console.warn(`⚠️ После фильтрации дубликатов (начальная загрузка): ${beforeFilterCount} -> ${reqs.length} требований`);
      }
      
      console.log('✅ Начальная загрузка: Всего требований после фильтрации:', reqs.length);
      
      const cats = Array.isArray(categoriesRes.data) ? categoriesRes.data : (categoriesRes.data?.items || []);
      const docs = Array.isArray(documentsRes.data) ? documentsRes.data : (documentsRes.data?.items || []);
      let conts = Array.isArray(contractsRes.data) ? contractsRes.data : (contractsRes.data?.items || []);
      let evts = Array.isArray(eventsRes.data) ? eventsRes.data : (eventsRes.data?.items || []);
      
      // Удаляем дубликаты договоров по ID и номеру
      const seenContractIds = new Set<number>();
      const seenContractNumbers = new Set<string>();
      const beforeContractFilterCount = conts.length;
      conts = conts.filter((contract: Contract) => {
        if (seenContractIds.has(contract.id)) {
          console.warn('⚠️ Дубликат договора по ID:', contract.id, contract.number);
          return false;
        }
        if (seenContractNumbers.has(contract.number)) {
          console.warn('⚠️ Дубликат договора по номеру:', contract.number);
          return false;
        }
        seenContractIds.add(contract.id);
        seenContractNumbers.add(contract.number);
        return true;
      });
      
      if (beforeContractFilterCount !== conts.length) {
        console.warn(`⚠️ После фильтрации дубликатов договоров: ${beforeContractFilterCount} -> ${conts.length}`);
      }
      
      // Удаляем дубликаты событий по ID и названию
      const seenEventIds = new Set<number>();
      const seenEventTitles = new Set<string>();
      evts = evts.filter((evt: Event) => {
        if (seenEventIds.has(evt.id)) return false;
        const key = `${evt.title}-${evt.date}`;
        if (seenEventTitles.has(key)) return false;
        seenEventIds.add(evt.id);
        seenEventTitles.add(key);
        return true;
      });

      if (clients.length > 0) {
        const currentClient = clients[0];
        setClient(currentClient);
        setCategoryId(currentClient.category_id || '');
        // Инициализируем значения - если false, то явно false, иначе пустая строка для "не выбрано"
        setHasWell(currentClient.has_well === true ? true : (currentClient.has_well === false ? false : ''));
        setHasRiver(currentClient.has_river === true ? true : (currentClient.has_river === false ? false : ''));
        setHasByproduct(currentClient.has_byproduct === true ? true : (currentClient.has_byproduct === false ? false : ''));
        setResponsiblePerson(currentClient.responsible_person || '');
      }

      setRequirements(reqs);
      setCategories(cats);
      setDocuments(docs);
      setContracts(conts);
      setEvents(evts);

      // Загрузка рисков для каждого требования
      const risksMap: Record<number, Risk[]> = {};
      for (const req of reqs) {
        try {
          const riskRes = await api.get(`/requirement/${req.id}/risks`);
          risksMap[req.id] = riskRes.data || [];
        } catch (error) {
          // Риски могут отсутствовать
        }
      }
      setRisks(risksMap);
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleRecalculate = async () => {
    if (!client) return;

    setRecalculating(true);
    try {
      // Для клиента передаем client_id, чтобы избежать ошибки
      // Явно передаем булевы значения - если не выбрано или пустая строка, значит false
      // Важно: если значение не было изменено пользователем (пустая строка), используем значение из клиента
      const requestData: any = {
        category_id: categoryId || client.category_id,
        has_well: hasWell === '' ? (client.has_well || false) : (hasWell === true || String(hasWell) === 'true' || hasWell === 1 || String(hasWell) === '1'),
        has_river: hasRiver === '' ? (client.has_river || false) : (hasRiver === true || String(hasRiver) === 'true' || hasRiver === 1 || String(hasRiver) === '1'),
        has_byproduct: hasByproduct === '' ? (client.has_byproduct || false) : (hasByproduct === true || String(hasByproduct) === 'true' || hasByproduct === 1 || String(hasByproduct) === '1'),
        responsible_person: responsiblePerson || client.responsible_person || '',
      };
      
      console.log('Пересчет требований с параметрами:', {
        category_id: requestData.category_id,
        has_well: requestData.has_well,
        has_river: requestData.has_river,
        has_byproduct: requestData.has_byproduct,
        'hasWell state': hasWell,
        'hasRiver state': hasRiver,
        'hasByproduct state': hasByproduct,
      });
      
      // Если есть client_id, передаем его (для админа)
      if (client.id) {
        requestData.client_id = client.id;
      }
      
      const response = await api.post('/requirement/recalculate', requestData);

      if (response.data.success) {
        // Обновляем данные клиента из ответа
        if (response.data.client) {
          const updatedClient = response.data.client;
          setClient(updatedClient);
          setCategoryId(updatedClient.category_id || '');
          setHasWell(updatedClient.has_well || false);
          setHasRiver(updatedClient.has_river || false);
          setHasByproduct(updatedClient.has_byproduct || false);
          setResponsiblePerson(updatedClient.responsible_person || '');
        }
        
        // Перезагружаем требования сразу с принудительным обновлением
        try {
          // Небольшая задержка, чтобы БД успела обновиться
          await new Promise(resolve => setTimeout(resolve, 100));
          
          // Используем тот же URL, что и при первоначальной загрузке
          const clientIdFromUrl = searchParams?.get('client_id');
          const requirementUrl = clientIdFromUrl 
            ? `/requirement?client_id=${clientIdFromUrl}&_t=${Date.now()}` 
            : `/requirement?_t=${Date.now()}`;
          
          // Добавляем timestamp для предотвращения кэширования
          const requirementsRes = await api.get(requirementUrl);
          let reqs = Array.isArray(requirementsRes.data) ? requirementsRes.data : (requirementsRes.data?.items || []);
          
          console.log('🔍 DEBUG (после пересчета): Полный ответ API:', JSON.stringify(requirementsRes.data, null, 2));
          console.log('🔍 DEBUG (после пересчета): Требования получены с бэкенда:', reqs.length, 'шт.');
          console.log('🔍 DEBUG (после пересчета): URL запроса:', requirementUrl);
          console.log('🔍 DEBUG (после пересчета): Тип данных:', Array.isArray(requirementsRes.data) ? 'массив' : 'объект');
          if (!Array.isArray(requirementsRes.data) && requirementsRes.data?.items) {
            console.log('🔍 DEBUG (после пересчета): Используется items, всего элементов:', requirementsRes.data.items.length);
          }
          console.log('🔍 DEBUG (после пересчета): Все требования:', reqs.map((r: Requirement) => ({ id: r.id, title: r.title })));
          
          // Удаляем дубликаты по ID и названию (на случай если они все же появились)
          const seenIds = new Set<number>();
          const seenTitles = new Set<string>();
          const beforeFilterCount = reqs.length;
          reqs = reqs.filter((req: Requirement) => {
            if (seenIds.has(req.id)) {
              console.warn('⚠️ Дубликат по ID:', req.id, req.title);
              return false;
            }
            if (seenTitles.has(req.title)) {
              console.warn('⚠️ Дубликат по названию:', req.title);
              return false;
            }
            seenIds.add(req.id);
            seenTitles.add(req.title);
            return true;
          });
          
          if (beforeFilterCount !== reqs.length) {
            console.warn(`⚠️ После фильтрации дубликатов: ${beforeFilterCount} -> ${reqs.length} требований`);
          }
          
          console.log('✅ Обновление требований после пересчета:', reqs.length, 'требований');
          console.log('✅ Все требования:', reqs.map((r: Requirement) => r.title));
          
          // Принудительно обновляем состояние - создаем полностью новый массив
          setRequirements([]); // Сначала очищаем
          await new Promise(resolve => setTimeout(resolve, 50));
          setRequirements([...reqs]); // Затем устанавливаем новые данные
          
          // Обновляем риски (упрощенно, без задержек)
          const risksMap: Record<number, Risk[]> = {};
          for (const req of reqs.slice(0, 10)) { // Только первые 10 для скорости
            try {
              const riskRes = await api.get(`/requirement/${req.id}/risks`);
              risksMap[req.id] = riskRes.data || [];
            } catch (error) {
              // Риски могут отсутствовать
            }
          }
          setRisks(risksMap);
        } catch (error) {
          console.error('Error reloading requirements:', error);
          // Если не удалось загрузить, все равно показываем успех
        }
        
        // Убрали alert - теперь просто обновляем данные без плашки
        console.log(`Требования успешно пересчитаны. Создано требований: ${response.data.requirements_count || 0}`);
      } else {
        alert('Ошибка при пересчете требований');
      }
    } catch (error: any) {
      console.error('Error recalculating requirements:', error);
      const errorMessage = error.response?.data?.message || error.response?.data?.error || 'Ошибка при пересчете требований';
      alert(errorMessage);
    } finally {
      setRecalculating(false);
      setLoading(false);
    }
  };


  const getStatusLabel = (status: string) => {
    switch (status) {
      case 'pending':
        return 'Ожидание';
      case 'in_progress':
        return 'В работе';
      case 'completed':
        return 'Выполнено';
      case 'not_completed':
        return 'Не выполнено';
      default:
        return status;
    }
  };

  const getStatusClass = (status: string) => {
    switch (status) {
      case 'completed':
        return styles.statusCompleted;
      case 'in_progress':
        return styles.statusInProgress;
      case 'not_completed':
        return styles.statusNotCompleted;
      default:
        return styles.statusPending;
    }
  };

  const formatDeadline = (deadline: string | null | undefined) => {
    if (!deadline) return '';
    const date = new Date(deadline);
    const day = date.getDate();
    const month = date.toLocaleDateString('ru-RU', { month: 'long' });
    if (day <= 10) {
      return `${day}.${String(date.getMonth() + 1).padStart(2, '0')}`;
    }
    return month;
  };

  const renderRequirementsTab = () => (
    <div className={styles.tabContent}>
        {requirements.length === 0 ? (
          <div className={styles.empty}>Нет требований</div>
        ) : (
        <div className={styles.tableWrapper}>
          <table className={styles.requirementsTable}>
            <thead>
              <tr>
                <th>Требования</th>
                <th>Основание</th>
                <th>Артефакты</th>
                <th>Год документа</th>
                <th>Статусы</th>
                <th>Срок выполнения</th>
                <th>Ответственный</th>
              </tr>
            </thead>
            <tbody>
              {requirements.map((req, index) => (
                <tr key={`${req.id}-${index}-${req.title}`}>
                  <td className={styles.requirementTitle}>{req.title}</td>
                  <td>
                    {req.basis ? (
                      <span className={styles.basisText}>
                        {req.basis}
                      </span>
                    ) : (
                      <span className={styles.noBasis}>—</span>
                    )}
                  </td>
                  <td>
                    {req.artifacts && req.artifacts.length > 0 ? (
                      <div className={styles.artifacts}>
                        {req.artifacts.map((artifact, idx) => (
                          <span key={idx} className={styles.artifact}>
                            {artifact}
                          </span>
                        ))}
                      </div>
                    ) : (
                      <span className={styles.noArtifacts}>—</span>
                    )}
                  </td>
                  <td>{req.document_year || new Date().getFullYear()}</td>
                  <td>
                    <span className={`${styles.statusBadge} ${getStatusClass(req.status)}`}>
                      {getStatusLabel(req.status)}
                    </span>
                  </td>
                  <td>{formatDeadline(req.deadline)}</td>
                  <td>{req.responsible_person || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );

  const renderArtifactsTab = () => (
    <div className={styles.tabContent}>
      <div className={styles.artifactsHeader}>
        <button
          onClick={() => router.push('/documents')}
          className={styles.uploadButton}
        >
          Загрузить документ
        </button>
      </div>
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
                  {doc.status === 'pending' && 'На проверке'}
                  {doc.status === 'approved' && 'Одобрен'}
                  {doc.status === 'rejected' && 'Отклонён'}
                  </span>
              </div>
              <button
                onClick={() => router.push('/documents')}
                className={styles.downloadButton}
              >
                Скачать
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );

  const handleDeleteEvent = async (eventId: number) => {
    if (!confirm('Удалить это событие?')) return;
    try {
      await api.delete(`/event/${eventId}`);
      setEvents(events.filter((e: Event) => e.id !== eventId));
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
        const res = await api.patch(`/event/${editingEvent.id}`, payload);
        setEvents(events.map((e: Event) => e.id === editingEvent.id ? { ...e, ...res.data } : e));
      } else {
        const res = await api.post('/event', payload);
        setEvents([...events, res.data]);
      }
      
      // Перезагружаем события для обновления
      const eventsRes = await api.get('/event');
      const evts = Array.isArray(eventsRes.data) ? eventsRes.data : (eventsRes.data?.items || []);
      const seenEventIds = new Set<number>();
      const seenEventTitles = new Set<string>();
      const uniqueEvts = evts.filter((evt: Event) => {
        if (seenEventIds.has(evt.id)) return false;
        const key = `${evt.title}-${evt.date}`;
        if (seenEventTitles.has(key)) return false;
        seenEventIds.add(evt.id);
        seenEventTitles.add(key);
        return true;
      });
      setEvents(uniqueEvts);
      
      setShowEventModal(false);
      setEditingEvent(null);
    } catch (error: any) {
      console.error('Error saving event:', error);
      const errorMsg = error.response?.data?.message || error.response?.data?.error || 'Ошибка при сохранении события';
      alert(errorMsg);
    }
  };

  const renderCalendarTab = () => {
    const sortedEvents = [...events].sort((a, b) => 
      new Date(a.date).getTime() - new Date(b.date).getTime()
    );
    const upcomingEvents = sortedEvents.filter((e) => !e.completed && new Date(e.date) >= new Date());
    const pastEvents = sortedEvents.filter((e) => e.completed || new Date(e.date) < new Date());
    const isAdmin = currentUser?.role === 'admin';
    
    console.log('Calendar tab - currentUser:', currentUser, 'isAdmin:', isAdmin);

    return (
      <div className={styles.tabContent}>
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
      </div>
    );
  };
  
  const EventModal = ({ event, onClose, onSave }: { event: Event | null, onClose: () => void, onSave: (data: any) => void }) => {
    const [title, setTitle] = useState(event?.title || '');
    const [date, setDate] = useState(event?.date ? (event.date.includes('T') ? event.date.split('T')[0] : event.date) : '');
    const [completed, setCompleted] = useState(event?.completed || false);

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
          <form onSubmit={handleSubmit} className={styles.modalForm}>
            <label>
              Название:
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className={styles.input}
                required
              />
            </label>
            <label>
              Дата:
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className={styles.input}
                required
              />
            </label>
            <label style={{ flexDirection: 'row', alignItems: 'center', gap: '0.5rem' }}>
              <input
                type="checkbox"
                checked={completed}
                onChange={(e) => setCompleted(e.target.checked)}
              />
              Выполнено
            </label>
            <div className={styles.modalButtons}>
              <button type="button" onClick={onClose} className={styles.cancelButton}>Отмена</button>
              <button
                type="submit"
                className={styles.saveButton}
                disabled={!title || !date}
              >
                Сохранить
              </button>
            </div>
          </form>
        </div>
      </div>
    );
  };

  const renderRisksTab = () => {
    const allRisks: Array<{ requirement: Requirement; risks: Risk[] }> = [];
    requirements.forEach((req: Requirement) => {
      if (risks[req.id] && risks[req.id].length > 0) {
        allRisks.push({ requirement: req, risks: risks[req.id] });
      }
    });

    return (
      <div className={styles.tabContent}>
        {allRisks.length === 0 ? (
          <div className={styles.empty}>Нет рисков</div>
        ) : (
          <div className={styles.risksList}>
            {allRisks.map(({ requirement, risks: reqRisks }) => (
              <div key={requirement.id} className={styles.riskCard}>
                <h3>{requirement.title}</h3>
                  <div className={styles.risks}>
                  {reqRisks.map((risk) => (
                      <div key={risk.id} className={styles.risk}>
                        <span className={styles.article}>Статья {risk.article}</span>
                        <span className={styles.fine}>
                          Штраф: {risk.fine_min.toLocaleString()} - {risk.fine_max.toLocaleString()} ₽
                        </span>
                      </div>
                    ))}
                  </div>
              </div>
            ))}
          </div>
        )}
      </div>
    );
  };

  const renderContractsTab = () => (
    <div className={styles.tabContent}>
      {contracts.length === 0 ? (
        <div className={styles.empty}>Нет договоров</div>
      ) : (
        <div className={styles.contractsList}>
          {contracts.map((contract) => (
            <div key={contract.id} className={styles.contractCard}>
              <div className={styles.contractHeader}>
                <h3>Договор №{contract.number}</h3>
                <span className={`${styles.statusBadge} ${getStatusClass(contract.status)}`}>
                  {contract.status === 'draft' && 'Черновик'}
                  {contract.status === 'active' && 'Активен'}
                  {contract.status === 'completed' && 'Завершён'}
                  {contract.status === 'cancelled' && 'Отменён'}
                </span>
              </div>
              {contract.date && (
                <div className={styles.contractDate}>
                  Дата: {new Date(contract.date).toLocaleDateString('ru-RU')}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );

  const renderLegislationTab = () => (
    <div className={styles.tabContent}>
      <div className={styles.empty}>Раздел "Изменения в законодательстве" будет добавлен в следующей версии</div>
    </div>
  );

  const renderCostsTab = () => (
    <div className={styles.tabContent}>
      <div className={styles.empty}>Раздел "Снижение затрат" будет добавлен в следующей версии</div>
    </div>
  );

  const renderTemplatesTab = () => (
    <div className={styles.tabContent}>
      <div className={styles.empty}>Раздел "Шаблоны" будет добавлен в следующей версии</div>
    </div>
  );

  if (loading) {
    return <div className={styles.loading}>Загрузка...</div>;
  }

  return (
    <div className={styles.requirements}>
      <header className={styles.header}>
        <div className={styles.headerContent}>
          <div>
            <h1>ГПБ</h1>
            <h2>Личный кабинет клиента</h2>
            <p className={styles.version}>Версия от 20.10.2025</p>
          </div>
        </div>
      </header>

      {/* Параметры площадки */}
      <div className={styles.filters}>
        <div className={styles.filtersContent}>
          <div className={styles.filterRow}>
            <label>Параметры площадки</label>
            {currentUser?.role === 'client' ? (
              // Для клиента - только просмотр (read-only)
              <div className={styles.filterGroup}>
                <div className={styles.readOnlyField}>
                  <span className={styles.readOnlyLabel}>Категория НВОС:</span>
                  <span className={styles.readOnlyValue}>
                    {client?.category_id ? categories.find(c => c.id === client.category_id)?.title || `Категория ${client.category_id}` : 'Не указана'}
                  </span>
                </div>
                <div className={styles.readOnlyField}>
                  <span className={styles.readOnlyLabel}>Водопользование:</span>
                  <span className={styles.readOnlyValue}>
                    {client?.has_well ? 'Скважина' : client?.has_river ? 'Река/озеро' : 'Без водопользования'}
                  </span>
                </div>
                <div className={styles.readOnlyField}>
                  <span className={styles.readOnlyLabel}>Побочный продукт:</span>
                  <span className={styles.readOnlyValue}>
                    {client?.has_byproduct ? 'Есть побочный продукт' : 'Нет побочного продукта/навоза/помёта'}
                  </span>
                </div>
                <div className={styles.readOnlyField}>
                  <span className={styles.readOnlyLabel}>Ответственный:</span>
                  <span className={styles.readOnlyValue}>
                    {client?.responsible_person || 'Не указан'}
                  </span>
                </div>
              </div>
            ) : (
              // Для админа и менеджера - редактируемая форма
              <>
                <div className={styles.filterGroup}>
                  <select
                    value={categoryId}
                    onChange={(e) => setCategoryId(e.target.value ? Number(e.target.value) : '')}
                    className={styles.filterSelect}
                  >
                    <option value="">Выберите категорию</option>
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.id}>
                        {cat.title}
                      </option>
                    ))}
                  </select>

                  <select
                    value={
                      hasWell || hasRiver 
                        ? (hasWell ? 'well' : hasRiver ? 'river' : '')
                        : (hasWell === false && hasRiver === false ? 'no' : '')
                    }
                    onChange={(e) => {
                      const val = e.target.value;
                      if (val === '') {
                        setHasWell('');
                        setHasRiver('');
                      } else if (val === 'no') {
                        setHasWell(false);
                        setHasRiver(false);
                      } else if (val === 'well') {
                        setHasWell(true);
                        setHasRiver(false);
                      } else if (val === 'river') {
                        setHasWell(false);
                        setHasRiver(true);
                      }
                    }}
                    className={styles.filterSelect}
                  >
                    <option value="">Водопользование</option>
                    <option value="no">Без водопользования</option>
                    <option value="well">Скважина</option>
                    <option value="river">Река/озеро</option>
                  </select>

                  <select
                    value={hasByproduct === '' ? '' : hasByproduct ? 'yes' : 'no'}
                    onChange={(e) => setHasByproduct(e.target.value === '' ? '' : e.target.value === 'yes')}
                    className={styles.filterSelect}
                  >
                    <option value="">Побочный продукт</option>
                    <option value="no">Нет побочного продукта/навоза/помёта</option>
                    <option value="yes">Есть побочный продукт</option>
                  </select>

                  <input
                    type="text"
                    placeholder="Ответственный (ФИО)"
                    value={responsiblePerson}
                    onChange={(e) => setResponsiblePerson(e.target.value)}
                    className={styles.filterInput}
                  />
                </div>
                <button
                  onClick={handleRecalculate}
                  disabled={recalculating}
                  className={styles.recalculateButton}
                >
                  {recalculating ? 'Пересчет...' : 'Пересчитать требования'}
                </button>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Табы */}
      <div className={styles.tabs}>
        <div
          className={`${styles.tab} ${activeTab === 'requirements' ? styles.tabActive : ''}`}
          onClick={() => setActiveTab('requirements')}
        >
          Карта требований
        </div>
        <div
          className={`${styles.tab} ${activeTab === 'artifacts' ? styles.tabActive : ''}`}
          onClick={() => setActiveTab('artifacts')}
        >
          Артефакты/хранилище
        </div>
        <div
          className={`${styles.tab} ${activeTab === 'calendar' ? styles.tabActive : ''}`}
          onClick={() => setActiveTab('calendar')}
        >
          Календарь событий
        </div>
        <div
          className={`${styles.tab} ${activeTab === 'risks' ? styles.tabActive : ''}`}
          onClick={() => setActiveTab('risks')}
        >
          Риски
        </div>
        <div
          className={`${styles.tab} ${activeTab === 'legislation' ? styles.tabActive : ''}`}
          onClick={() => setActiveTab('legislation')}
        >
          Изменения в законодательстве
        </div>
        <div
          className={`${styles.tab} ${activeTab === 'contracts' ? styles.tabActive : ''}`}
          onClick={() => setActiveTab('contracts')}
        >
          Договора/счета/акты
        </div>
        <div
          className={`${styles.tab} ${activeTab === 'costs' ? styles.tabActive : ''}`}
          onClick={() => setActiveTab('costs')}
        >
          Снижение затрат
        </div>
        <div
          className={`${styles.tab} ${activeTab === 'templates' ? styles.tabActive : ''}`}
          onClick={() => setActiveTab('templates')}
        >
          Шаблоны
        </div>
      </div>

      {/* Контент вкладок */}
      <main className={styles.content}>
        {activeTab === 'requirements' && renderRequirementsTab()}
        {activeTab === 'artifacts' && renderArtifactsTab()}
        {activeTab === 'calendar' && renderCalendarTab()}
        {activeTab === 'risks' && renderRisksTab()}
        {activeTab === 'legislation' && renderLegislationTab()}
        {activeTab === 'contracts' && renderContractsTab()}
        {activeTab === 'costs' && renderCostsTab()}
        {activeTab === 'templates' && renderTemplatesTab()}
      </main>
    </div>
  );
}
