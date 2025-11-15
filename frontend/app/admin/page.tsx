'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import api from '@/lib/api';
import { Client, Category, Requirement, User, Npa } from '@/lib/types';
import styles from './admin.module.scss';

export default function AdminPage() {
  const router = useRouter();
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [activeTab, setActiveTab] = useState<'dashboard' | 'users' | 'clients' | 'requirements' | 'questionnaire' | 'npa'>('dashboard');
  const [clients, setClients] = useState<Client[]>([]);
  const [requirements, setRequirements] = useState<Requirement[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [npaList, setNpaList] = useState<Npa[]>([]);
  const [loading, setLoading] = useState(true);
  const [showClientForm, setShowClientForm] = useState(false);
  const [filterClientId, setFilterClientId] = useState<string>('');
  const [showRequirementForm, setShowRequirementForm] = useState(false);
  const [showUserForm, setShowUserForm] = useState(false);
  const [showNpaForm, setShowNpaForm] = useState(false);
  const [selectedClient, setSelectedClient] = useState<Client | null>(null);
  const [selectedRequirement, setSelectedRequirement] = useState<Requirement | null>(null);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [selectedNpa, setSelectedNpa] = useState<Npa | null>(null);
  
  // Форма редактирования требования
  const [requirementForm, setRequirementForm] = useState({
    client_id: '',
    title: '',
    status: 'pending' as Requirement['status'],
    deadline: '',
    responsible_person: '',
    basis: '',
  });

  // Форма клиента
  const [clientForm, setClientForm] = useState({
    name: '',
    category_id: '',
    has_well: false,
    has_river: false,
    has_byproduct: false,
    responsible_person: '',
  });

  // Форма пользователя
  const [userForm, setUserForm] = useState({
    name: '',
    email: '',
    password: '',
    role: 'client',
    client_id: '',
  });

  // Форма НПА
  const [npaForm, setNpaForm] = useState({
    code: '',
    title: '',
    link: '',
    block: '',
  });

  useEffect(() => {
    checkAccess();
    loadData();
  }, []);

  // Перезагружаем требования при изменении фильтра клиента
  useEffect(() => {
    if (activeTab === 'requirements') {
      loadRequirements();
    }
  }, [filterClientId, activeTab]);

  const loadRequirements = async () => {
    try {
      // КРИТИЧЕСКИ ВАЖНО: Если выбран клиент, загружаем ТОЛЬКО его требования
      // Если клиент не выбран, показываем пустой список (админ должен выбрать клиента)
      if (!filterClientId) {
        setRequirements([]);
        return;
      }
      
      const requirementUrl = `/requirement?client_id=${filterClientId}`;
      
      const requirementsRes = await api.get(requirementUrl);
      let reqs = Array.isArray(requirementsRes.data) 
        ? requirementsRes.data 
        : (requirementsRes.data?.items || []);
      
      // ДОПОЛНИТЕЛЬНАЯ ФИЛЬТРАЦИЯ: Убеждаемся, что показываем только требования выбранного клиента
      const clientIdNum = parseInt(filterClientId, 10);
      reqs = reqs.filter((req: Requirement) => req.client_id === clientIdNum);
      
      setRequirements(reqs);
    } catch (error) {
      console.error('Error loading requirements:', error);
      setRequirements([]);
    }
  };

  const checkAccess = async () => {
    try {
      const res = await api.get('/auth/me');
      setCurrentUser(res.data);
      if (res.data.role !== 'admin') {
        alert('Доступ запрещен. Только администраторы могут заходить в админ панель.');
        router.push('/dashboard');
      }
    } catch (error) {
      router.push('/login');
    }
  };

  const loadData = async () => {
    try {
      // КРИТИЧЕСКИ ВАЖНО: Если выбран клиент, загружаем требования только для него
      // Иначе загружаем все требования (для админа)
      const requirementUrl = filterClientId 
        ? `/requirement?client_id=${filterClientId}`
        : '/requirement';
      
      const [clientsRes, requirementsRes, categoriesRes, usersRes, npaRes] = await Promise.all([
        api.get('/client'),
        api.get(requirementUrl),
        api.get('/category'),
        api.get('/user').catch(() => ({ data: [] })),
        api.get('/npa').catch(() => ({ data: [] })),
      ]);

      setClients(Array.isArray(clientsRes.data) ? clientsRes.data : (clientsRes.data?.items || []));
      setRequirements(Array.isArray(requirementsRes.data) ? requirementsRes.data : (requirementsRes.data?.items || []));
      setCategories(Array.isArray(categoriesRes.data) ? categoriesRes.data : (categoriesRes.data?.items || []));
      setUsers(Array.isArray(usersRes.data) ? usersRes.data : (usersRes.data?.items || []));
      setNpaList(Array.isArray(npaRes.data) ? npaRes.data : (npaRes.data?.items || []));
    } catch (error) {
      console.error('Error loading data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleEditRequirement = (req: Requirement) => {
    setSelectedRequirement(req);
    setRequirementForm({
      client_id: req.client_id.toString(),
      title: req.title,
      status: req.status,
      deadline: req.deadline || '',
      responsible_person: req.responsible_person || '',
      basis: req.basis || '',
    });
    setShowRequirementForm(true);
  };

  const handleSaveRequirement = async () => {
    if (!requirementForm.title) {
      alert('Название требования обязательно');
      return;
    }
    
    try {
      if (selectedRequirement) {
        // Обновление существующего
        const { client_id, ...updateData } = requirementForm;
        await api.patch(`/requirement/${selectedRequirement.id}`, updateData);
        alert('Требование успешно обновлено!');
      } else {
        // Создание нового
        if (!requirementForm.client_id) {
          alert('Выберите клиента');
          return;
        }
        await api.post('/requirement', {
          ...requirementForm,
          client_id: parseInt(requirementForm.client_id),
        });
        alert('Требование успешно создано!');
      }
      setShowRequirementForm(false);
      setSelectedRequirement(null);
      // Перезагружаем требования для выбранного клиента
      await loadRequirements();
    } catch (error: any) {
      alert(error.response?.data?.message || 'Ошибка при сохранении требования');
    }
  };

  const handleDeleteRequirement = async (req: Requirement) => {
    if (!confirm(`Удалить требование "${req.title}"?`)) return;
    
    try {
      await api.delete(`/requirement/${req.id}`);
      alert('Требование удалено!');
      // Перезагружаем требования для выбранного клиента
      await loadRequirements();
    } catch (error: any) {
      alert(error.response?.data?.message || 'Ошибка при удалении требования');
    }
  };

  const handleEditClient = (client: Client) => {
    setSelectedClient(client);
    setClientForm({
      name: client.name,
      category_id: client.category_id.toString(),
      has_well: client.has_well,
      has_river: client.has_river,
      has_byproduct: client.has_byproduct,
      responsible_person: client.responsible_person || '',
    });
    setShowClientForm(true);
  };

  const handleSaveClient = async () => {
    if (!clientForm.name || !clientForm.category_id) {
      alert('Название и категория обязательны');
      return;
    }
    
    try {
      const clientData = {
        name: clientForm.name,
        category_id: parseInt(clientForm.category_id),
        has_well: clientForm.has_well,
        has_river: clientForm.has_river,
        has_byproduct: clientForm.has_byproduct,
        responsible_person: clientForm.responsible_person,
      };
      
      if (selectedClient) {
        await api.patch(`/client/${selectedClient.id}`, clientData);
        alert('Клиент успешно обновлен!');
      } else {
        await api.post('/client', clientData);
        alert('Клиент успешно создан! Требования автоматически сформированы.');
      }
      
      setShowClientForm(false);
      setSelectedClient(null);
      setClientForm({
        name: '',
        category_id: '',
        has_well: false,
        has_river: false,
        has_byproduct: false,
        responsible_person: '',
      });
      await loadData();
      if (!selectedClient) {
        // После создания клиента показываем уведомление
        const newClient = await api.get('/client').then(res => {
          const clients = Array.isArray(res.data) ? res.data : (res.data?.items || []);
          return clients[clients.length - 1]; // Последний созданный
        });
        
        if (newClient) {
          // Загружаем требования для нового клиента
          const reqs = await api.get(`/requirement?client_id=${newClient.id}`).then(res => {
            const data = Array.isArray(res.data) ? res.data : (res.data?.items || []);
            return data;
          });
          
          const reqCount = reqs.length;
          const message = `Клиент "${newClient.name}" успешно создан!\n\nАвтоматически сформировано требований: ${reqCount}\n\nХотите перейти к просмотру требований этого клиента?`;
          
          if (confirm(message)) {
            // Переходим к требованиям с фильтром по клиенту
            setFilterClientId(newClient.id.toString());
            setActiveTab('requirements');
          } else {
            setActiveTab('clients');
          }
        } else {
          setActiveTab('clients');
        }
      }
    } catch (error: any) {
      alert(error.response?.data?.message || 'Ошибка при сохранении клиента');
    }
  };

  const handleDeleteClient = async (client: Client) => {
    if (!confirm(`Удалить клиента "${client.name}"? Все связанные требования также будут удалены.`)) return;
    
    try {
      await api.delete(`/client/${client.id}`);
      alert('Клиент удален!');
      await loadData();
    } catch (error: any) {
      alert(error.response?.data?.message || 'Ошибка при удалении клиента');
    }
  };

  const handleEditUser = (user: User) => {
    setSelectedUser(user);
    setUserForm({
      name: user.name,
      email: user.email,
      password: '',
      role: user.role,
      client_id: user.client_id?.toString() || '',
    });
    setShowUserForm(true);
  };

  const handleSaveUser = async () => {
    if (!userForm.name || !userForm.email) {
      alert('Имя и email обязательны');
      return;
    }
    
    if (!selectedUser && !userForm.password) {
      alert('Пароль обязателен при создании пользователя');
      return;
    }
    
    try {
      const userData: any = {
        name: userForm.name,
        email: userForm.email,
        role: userForm.role,
        client_id: userForm.client_id ? parseInt(userForm.client_id) : null,
      };
      
      if (userForm.password) {
        userData.password = userForm.password;
      }
      
      if (selectedUser) {
        await api.patch(`/user/${selectedUser.id}`, userData);
        alert('Пользователь успешно обновлен!');
      } else {
        await api.post('/user', userData);
        alert('Пользователь успешно создан!');
      }
      
      setShowUserForm(false);
      setSelectedUser(null);
      setUserForm({
        name: '',
        email: '',
        password: '',
        role: 'client',
        client_id: '',
      });
      await loadData();
    } catch (error: any) {
      alert(error.response?.data?.message || error.response?.data || 'Ошибка при сохранении пользователя');
    }
  };

  const handleDeleteUser = async (user: User) => {
    if (user.id === currentUser?.id) {
      alert('Нельзя удалить самого себя');
      return;
    }
    if (!confirm(`Удалить пользователя "${user.name}"?`)) return;
    
    try {
      await api.delete(`/user/${user.id}`);
      alert('Пользователь удален!');
      await loadData();
    } catch (error: any) {
      alert(error.response?.data?.message || 'Ошибка при удалении пользователя');
    }
  };

  const handleEditNpa = (npa: Npa) => {
    setSelectedNpa(npa);
    setNpaForm({
      code: npa.code,
      title: npa.title,
      link: npa.link || '',
      block: npa.block || '',
    });
    setShowNpaForm(true);
  };

  const handleSaveNpa = async () => {
    if (!npaForm.code || !npaForm.title) {
      alert('Код и название обязательны');
      return;
    }
    
    try {
      if (selectedNpa) {
        await api.patch(`/npa/${selectedNpa.id}`, npaForm);
        alert('НПА успешно обновлен!');
      } else {
        await api.post('/npa', npaForm);
        alert('НПА успешно создан!');
      }
      
      setShowNpaForm(false);
      setSelectedNpa(null);
      setNpaForm({
        code: '',
        title: '',
        link: '',
        block: '',
      });
      await loadData();
    } catch (error: any) {
      alert(error.response?.data?.message || 'Ошибка при сохранении НПА');
    }
  };

  const handleDeleteNpa = async (npa: Npa) => {
    if (!confirm(`Удалить НПА "${npa.code}"?`)) return;
    
    try {
      await api.delete(`/npa/${npa.id}`);
      alert('НПА удален!');
      await loadData();
    } catch (error: any) {
      alert(error.response?.data?.message || 'Ошибка при удалении НПА');
    }
  };

  const handleCreateClient = async (e: React.FormEvent) => {
    e.preventDefault();
    await handleSaveClient();
  };

  if (loading || !currentUser || currentUser.role !== 'admin') {
    return <div className={styles.loading}>Загрузка...</div>;
  }

  return (
    <div className={styles.admin}>
      <header className={styles.header}>
        <h1>Админ панель</h1>
        <div style={{display: 'flex', gap: '1rem', alignItems: 'center'}}>
          <button onClick={() => router.push('/dashboard')} className={styles.backButton}>
            Вернуться в кабинет
          </button>
          <button 
            onClick={() => {
              // Удаляем токен
              if (typeof window !== 'undefined') {
                const Cookies = require('js-cookie');
                Cookies.remove('auth_token');
              }
              // Перенаправляем на страницу входа
              router.push('/login');
            }} 
            className={styles.logoutButton}
          >
            Выйти
          </button>
        </div>
      </header>

      <div className={styles.tabs}>
        <button
          className={`${styles.tab} ${activeTab === 'dashboard' ? styles.active : ''}`}
          onClick={() => setActiveTab('dashboard')}
        >
          Дашборд
        </button>
        <button
          className={`${styles.tab} ${activeTab === 'questionnaire' ? styles.active : ''}`}
          onClick={() => setActiveTab('questionnaire')}
        >
          Анкета клиента
        </button>
        <button
          className={`${styles.tab} ${activeTab === 'clients' ? styles.active : ''}`}
          onClick={() => setActiveTab('clients')}
        >
          Клиенты
        </button>
        <button
          className={`${styles.tab} ${activeTab === 'requirements' ? styles.active : ''}`}
          onClick={() => setActiveTab('requirements')}
        >
          Требования
        </button>
        <button
          className={`${styles.tab} ${activeTab === 'users' ? styles.active : ''}`}
          onClick={() => setActiveTab('users')}
        >
          Пользователи
        </button>
        <button
          className={`${styles.tab} ${activeTab === 'npa' ? styles.active : ''}`}
          onClick={() => setActiveTab('npa')}
        >
          Справочник НПА
        </button>
      </div>

      <main className={styles.content}>
        {activeTab === 'dashboard' && (
          <div className={styles.section}>
            <h2>Дашборд</h2>
            <div className={styles.dashboardGrid}>
              <div className={styles.dashboardCard}>
                <h3>КПЭ соответствия</h3>
                <div className={styles.kpiValue}>
                  {(() => {
                    const completed = requirements.filter((r: Requirement) => r.status === 'completed').length;
                    const total = requirements.length;
                    const percentage = total > 0 ? Math.round((completed / total) * 100) : 0;
                    return `${percentage}%`;
                  })()}
                </div>
                <div className={styles.progressBar}>
                  <div 
                    className={styles.progressFill}
                    style={{
                      width: `${(() => {
                        const completed = requirements.filter((r: Requirement) => r.status === 'completed').length;
                        const total = requirements.length;
                        return total > 0 ? (completed / total) * 100 : 0;
                      })()}%`
                    }}
                  />
                </div>
                <div className={styles.statusCounts}>
                  <span className={styles.statusBadge} style={{background: '#d4edda', color: '#155724'}}>
                    Выполнено: {requirements.filter((r: Requirement) => r.status === 'completed').length}
                  </span>
                  <span className={styles.statusBadge} style={{background: '#fff3cd', color: '#856404'}}>
                    В работе: {requirements.filter((r: Requirement) => r.status === 'in_progress').length}
                  </span>
                  <span className={styles.statusBadge} style={{background: '#f8d7da', color: '#721c24'}}>
                    Просрочено: {requirements.filter((r: Requirement) => r.status === 'not_completed').length}
                  </span>
                </div>
              </div>
              
              <div className={styles.dashboardCard}>
                <h3>Быстрые действия</h3>
                <div className={styles.quickActions}>
                  <button 
                    onClick={() => setActiveTab('questionnaire')}
                    className={styles.actionButton}
                    style={{background: '#28a745', color: 'white'}}
                  >
                    Создать нового клиента
                  </button>
                  <button 
                    onClick={() => setActiveTab('requirements')}
                    className={styles.actionButton}
                    style={{background: 'white', color: '#333', border: '1px solid #ddd'}}
                  >
                    Просмотреть все требования
                  </button>
                  <button 
                    onClick={() => setActiveTab('clients')}
                    className={styles.actionButton}
                    style={{background: 'white', color: '#333', border: '1px solid #ddd'}}
                  >
                    Управление клиентами
                  </button>
                </div>
              </div>
              
              <div className={styles.dashboardCard}>
                <h3>Статистика</h3>
                <div className={styles.statsList}>
                  <div className={styles.statItem}>
                    <span className={styles.statLabel}>Всего клиентов:</span>
                    <span className={styles.statValue}>{clients.length}</span>
                  </div>
                  <div className={styles.statItem}>
                    <span className={styles.statLabel}>Всего требований:</span>
                    <span className={styles.statValue}>{requirements.length}</span>
                  </div>
                  <div className={styles.statItem}>
                    <span className={styles.statLabel}>Всего пользователей:</span>
                    <span className={styles.statValue}>{users.length}</span>
                  </div>
                  <div className={styles.statItem}>
                    <span className={styles.statLabel}>НПА в справочнике:</span>
                    <span className={styles.statValue}>{npaList.length}</span>
                  </div>
                </div>
              </div>
            </div>
            
            <div className={styles.infoBox}>
              <h3>Как это работает:</h3>
              <ol className={styles.workflowList}>
                <li><strong>Создание клиента:</strong> Заполните анкету нового клиента (вкладка "Анкета клиента"). Укажите категорию НВОС и параметры площадки.</li>
                <li><strong>Автоматическая генерация требований:</strong> После создания клиента система автоматически формирует требования на основе категории и параметров (скважина, река, побочный продукт).</li>
                <li><strong>Управление требованиями:</strong> Во вкладке "Требования" вы можете редактировать, добавлять или удалять требования для любого клиента.</li>
                <li><strong>Просмотр личного кабинета клиента:</strong> В таблице клиентов нажмите "Просмотреть кабинет" чтобы увидеть, как клиент видит свои требования.</li>
                <li><strong>Создание пользователя:</strong> Во вкладке "Пользователи" создайте аккаунт для клиента, чтобы он мог войти в свой личный кабинет.</li>
              </ol>
            </div>
          </div>
        )}
        
        {activeTab === 'questionnaire' && (
          <div className={styles.section}>
            <h2>Анкета нового клиента (экология)</h2>
            <p className={styles.version}>Версия от 20.10.2025</p>
            
            <div className={styles.infoBox} style={{marginBottom: '2rem', background: '#e7f3ff', padding: '1rem', borderRadius: '0.5rem'}}>
              <strong>💡 Как это работает:</strong> После заполнения анкеты и нажатия "Создать клиента" система автоматически сформирует все необходимые требования на основе выбранной категории НВОС и параметров площадки (скважина, река, побочный продукт). Вы сможете сразу перейти к просмотру сформированных требований.
            </div>
            
            <form className={styles.questionnaireForm} onSubmit={handleCreateClient}>
              <div className={styles.formSection}>
                <h3>1) Данные юрлица и контакты</h3>
                <div className={styles.formRow}>
                  <label>Юрлицо / бренд *</label>
                  <input
                    type="text"
                    value={clientForm.name}
                    onChange={(e) => setClientForm({...clientForm, name: e.target.value})}
                    placeholder="ООО 'Название компании'"
                    required
                  />
                </div>
                <div className={styles.formRow}>
                  <label>ИНН / ОГРН</label>
                  <input
                    type="text"
                    placeholder="ИНН: 1234567890, ОГРН: 1234567890123"
                  />
                </div>
                <div className={styles.formRow}>
                  <label>ОКВЭД(ы) / сфера деятельности</label>
                  <input
                    type="text"
                    placeholder="Например: 38.21 - Обработка отходов"
                  />
                </div>
                <div className={styles.formRow}>
                  <label>Категория НВОС *</label>
                  <select
                    value={clientForm.category_id}
                    onChange={(e) => setClientForm({...clientForm, category_id: e.target.value})}
                    required
                  >
                    <option value="">Выберите категорию</option>
                    {categories.map((cat: Category) => (
                      <option key={cat.id} value={cat.id}>{cat.title}</option>
                    ))}
                  </select>
                  <small style={{color: '#666', fontSize: '0.875rem', marginTop: '0.25rem', display: 'block'}}>
                    Категория определяет базовый набор требований. I категория - самые строгие требования, IV - минимальные.
                  </small>
                </div>
                <div className={styles.formRow}>
                  <label>Ответственный (ФИО, роль)</label>
                  <input
                    type="text"
                    value={clientForm.responsible_person}
                    onChange={(e) => setClientForm({...clientForm, responsible_person: e.target.value})}
                    placeholder="Иванов Иван Иванович, эколог"
                  />
                </div>
                <div className={styles.formRow}>
                  <label>Email / телефон</label>
                  <div style={{display: 'flex', gap: '1rem'}}>
                    <input
                      type="email"
                      placeholder="email@example.com"
                      style={{flex: 1}}
                    />
                    <input
                      type="tel"
                      placeholder="+7 (999) 123-45-67"
                      style={{flex: 1}}
                    />
                  </div>
                </div>
              </div>

              <div className={styles.formSection}>
                <h3>2) Параметры площадки (для автоматического формирования требований)</h3>
                <div className={styles.infoBox} style={{background: '#fff3cd', padding: '0.75rem', borderRadius: '0.375rem', marginBottom: '1rem'}}>
                  <strong>⚠️ Важно:</strong> Эти параметры влияют на автоматическую генерацию требований. Если у клиента есть скважина или река, добавятся требования по водопользованию. Если есть побочный продукт (животноводство), добавятся соответствующие требования.
                </div>
                <div className={styles.formRow}>
                  <label>Источник водопользования</label>
                  <select
                    onChange={(e) => {
                      const val = e.target.value;
                      setClientForm({
                        ...clientForm,
                        has_well: val === 'well',
                        has_river: val === 'river',
                      });
                    }}
                    value={clientForm.has_well ? 'well' : clientForm.has_river ? 'river' : ''}
                  >
                    <option value="">Нет водопользования</option>
                    <option value="well">Скважина (подземные воды)</option>
                    <option value="river">Река/озеро (поверхностные воды)</option>
                  </select>
                </div>
                <div className={styles.formRow}>
                  <label>
                    <input
                      type="checkbox"
                      checked={clientForm.has_byproduct}
                      onChange={(e) => setClientForm({...clientForm, has_byproduct: e.target.checked})}
                    />
                    Есть побочный продукт (животноводство: навоз, помёт)
                  </label>
                </div>
              </div>

              <div className={styles.formSection}>
                <h3>3) Что произойдет после создания:</h3>
                <ul style={{paddingLeft: '1.5rem', color: '#666'}}>
                  <li>Система автоматически сформирует требования на основе категории НВОС</li>
                  <li>Если указана скважина или река - добавятся требования по водопользованию</li>
                  <li>Если указан побочный продукт - добавятся требования по обращению с отходами животноводства</li>
                  <li>Все требования будут доступны в личном кабинете клиента</li>
                </ul>
              </div>

              <button type="submit" className={styles.submitButton}>
                ✅ Создать клиента и автоматически сформировать требования
              </button>
            </form>
          </div>
        )}

        {activeTab === 'clients' && (
          <div className={styles.section}>
            <div className={styles.sectionHeader}>
              <h2>Клиенты</h2>
              <button 
                onClick={() => {
                  setSelectedClient(null);
                  setClientForm({
                    name: '',
                    category_id: '',
                    has_well: false,
                    has_river: false,
                    has_byproduct: false,
                    responsible_person: '',
                  });
                  setShowClientForm(true);
                }} 
                className={styles.addButton}
              >
                + Добавить клиента
              </button>
            </div>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Название</th>
                  <th>Категория</th>
                  <th>Скважина</th>
                  <th>Река</th>
                  <th>Побочный продукт</th>
                  <th>Ответственный</th>
                  <th>Действия</th>
                </tr>
              </thead>
              <tbody>
                {clients.map((client) => (
                  <tr key={client.id}>
                    <td>{client.id}</td>
                    <td>{client.name}</td>
                    <td>{categories.find(c => c.id === client.category_id)?.title || client.category_id}</td>
                    <td>{client.has_well ? 'Да' : 'Нет'}</td>
                    <td>{client.has_river ? 'Да' : 'Нет'}</td>
                    <td>{client.has_byproduct ? 'Да' : 'Нет'}</td>
                    <td>{client.responsible_person || '—'}</td>
                    <td>
                      <div className={styles.actionButtons}>
                        <button 
                          onClick={() => {
                            // Сохраняем выбранного клиента в localStorage для фильтрации
                            localStorage.setItem('admin_view_client_id', client.id.toString());
                            router.push(`/requirements?client_id=${client.id}`);
                          }}
                          className={styles.viewButton}
                          style={{background: '#4a90e2', color: 'white', marginRight: '0.5rem'}}
                        >
                          Просмотреть кабинет
                        </button>
                        <button 
                          onClick={() => handleEditClient(client)}
                          className={styles.editButton}
                        >
                          Редактировать
                        </button>
                        <button 
                          onClick={() => handleDeleteClient(client)}
                          className={styles.deleteButton}
                        >
                          Удалить
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {activeTab === 'requirements' && (
          <div className={styles.section}>
            <div className={styles.sectionHeader}>
              <h2>Управление требованиями</h2>
              <div className={styles.headerActions}>
                <select
                  value={filterClientId}
                  onChange={(e) => setFilterClientId(e.target.value)}
                  className={styles.filterSelect}
                >
                  <option value="">Выберите клиента</option>
                  {clients.map((client: Client) => (
                    <option key={client.id} value={client.id.toString()}>{client.name}</option>
                  ))}
                </select>
                {filterClientId && (
                  <button
                    onClick={async () => {
                      if (!confirm('Пересчитать требования для этого клиента? Все текущие требования будут удалены и созданы заново.')) {
                        return;
                      }
                      try {
                        const client = clients.find((c: Client) => c.id.toString() === filterClientId);
                        if (!client) return;
                        
                        const response = await api.post('/requirement/recalculate', {
                          client_id: client.id,
                          category_id: client.category_id,
                          has_well: client.has_well || false,
                          has_river: client.has_river || false,
                          has_byproduct: client.has_byproduct || false,
                          responsible_person: client.responsible_person || '',
                        });
                        
                        if (response.data.success) {
                          alert(`Требования успешно пересчитаны! Создано требований: ${response.data.count || 0}`);
                          await loadRequirements();
                        } else {
                          alert('Ошибка при пересчете требований');
                        }
                      } catch (error: any) {
                        alert(error.response?.data?.message || 'Ошибка при пересчете требований');
                      }
                    }}
                    className={styles.recalculateButton}
                    style={{ marginRight: '10px', backgroundColor: '#28a745', color: 'white', padding: '8px 16px', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
                  >
                    🔄 Пересчитать требования
                  </button>
                )}
                <button 
                  onClick={() => {
                    setSelectedRequirement(null);
                    setRequirementForm({
                      client_id: clients.length > 0 ? clients[0].id.toString() : '',
                      title: '',
                      status: 'pending',
                      deadline: '',
                      responsible_person: '',
                      basis: '',
                    });
                    setShowRequirementForm(true);
                  }}
                  className={styles.addButton}
                >
                  + Добавить требование
                </button>
              </div>
            </div>
            
            {requirements.length === 0 ? (
              <div className={styles.emptyState}>
                <p>Нет требований для отображения</p>
              </div>
            ) : (
              <>
                <div className={styles.tableWrapper}>
                  <table className={styles.table}>
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>Требование</th>
                        <th>Клиент</th>
                        <th>Статус</th>
                        <th>Срок</th>
                        <th>Ответственный</th>
                        <th>Основание</th>
                        <th>Действия</th>
                      </tr>
                    </thead>
                    <tbody>
                      {requirements.map((req) => (
                        <tr key={req.id}>
                          <td className={styles.idCell}>{req.id}</td>
                          <td className={styles.titleCell}>{req.title}</td>
                          <td>{clients.find(c => c.id === req.client_id)?.name || req.client_id}</td>
                          <td>
                            <span className={`${styles.statusBadge} ${
                              req.status === 'pending' ? styles.statusPending :
                              req.status === 'in_progress' ? styles.statusIn_progress :
                              req.status === 'completed' ? styles.statusCompleted :
                              ''
                            }`}>
                              {req.status === 'pending' ? 'Ожидание' : req.status === 'in_progress' ? 'В работе' : req.status === 'completed' ? 'Выполнено' : req.status}
                            </span>
                          </td>
                          <td>{req.deadline ? new Date(req.deadline).toLocaleDateString('ru-RU') : '—'}</td>
                          <td>{req.responsible_person || '—'}</td>
                          <td className={styles.basisCell}>{req.basis || '—'}</td>
                          <td>
                            <div className={styles.actionButtons}>
                              <button 
                                onClick={() => {
                                  router.push(`/requirements?client_id=${req.client_id}`);
                                }}
                                className={styles.viewButton}
                                title="Просмотреть"
                              >
                                Просмотреть
                              </button>
                              <button 
                                onClick={() => handleEditRequirement(req)}
                                className={styles.editButton}
                                title="Редактировать"
                              >
                                Редактировать
                              </button>
                              <button 
                                onClick={() => handleDeleteRequirement(req)}
                                className={styles.deleteButton}
                                title="Удалить"
                              >
                                Удалить
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {filterClientId && (
                  <div className={styles.filterInfo}>
                    Показано требований: <strong>{requirements.filter((req: Requirement) => req.client_id.toString() === filterClientId).length}</strong> из <strong>{requirements.length}</strong>
                  </div>
                )}
              </>
            )}
          </div>
        )}

        {activeTab === 'users' && (
          <div className={styles.section}>
            <div className={styles.sectionHeader}>
              <h2>Управление пользователями</h2>
              <button 
                onClick={() => {
                  setSelectedUser(null);
                  setUserForm({
                    name: '',
                    email: '',
                    password: '',
                    role: 'client',
                    client_id: '',
                  });
                  setShowUserForm(true);
                }}
                className={styles.addButton}
              >
                + Добавить пользователя
              </button>
            </div>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Имя</th>
                  <th>Email</th>
                  <th>Роль</th>
                  <th>Клиент</th>
                  <th>Действия</th>
                </tr>
              </thead>
              <tbody>
                {users.map((user) => (
                  <tr key={user.id}>
                    <td>{user.id}</td>
                    <td>{user.name}</td>
                    <td>{user.email}</td>
                    <td>{user.role}</td>
                    <td>{user.client_id ? clients.find(c => c.id === user.client_id)?.name || user.client_id : '—'}</td>
                    <td>
                      <div className={styles.actionButtons}>
                        <button 
                          onClick={() => handleEditUser(user)}
                          className={styles.editButton}
                        >
                          Редактировать
                        </button>
                        {user.id !== currentUser?.id && (
                          <button 
                            onClick={() => handleDeleteUser(user)}
                            className={styles.deleteButton}
                          >
                            Удалить
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {activeTab === 'npa' && (
          <div className={styles.section}>
            <div className={styles.sectionHeader}>
              <h2>Справочник НПА (нормативно-правовые акты)</h2>
              <button 
                onClick={() => {
                  setSelectedNpa(null);
                  setNpaForm({
                    code: '',
                    title: '',
                    link: '',
                    block: '',
                  });
                  setShowNpaForm(true);
                }}
                className={styles.addButton}
              >
                + Добавить НПА
              </button>
            </div>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Код</th>
                  <th>Название</th>
                  <th>Ссылка</th>
                  <th>Блок</th>
                  <th>Действия</th>
                </tr>
              </thead>
              <tbody>
                {npaList.map((npa) => (
                  <tr key={npa.id}>
                    <td>{npa.id}</td>
                    <td>{npa.code}</td>
                    <td>{npa.title}</td>
                    <td>{npa.link ? <a href={npa.link} target="_blank" rel="noopener noreferrer">Ссылка</a> : '—'}</td>
                    <td>{npa.block || '—'}</td>
                    <td>
                      <div className={styles.actionButtons}>
                        <button 
                          onClick={() => handleEditNpa(npa)}
                          className={styles.editButton}
                        >
                          Редактировать
                        </button>
                        <button 
                          onClick={() => handleDeleteNpa(npa)}
                          className={styles.deleteButton}
                        >
                          Удалить
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>

      {/* Модальное окно для требования */}
      {showRequirementForm && (
        <div className={styles.modal} onClick={() => setShowRequirementForm(false)}>
          <div className={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <h3>{selectedRequirement ? 'Редактировать требование' : 'Добавить требование'}</h3>
            {!selectedRequirement && (
              <div className={styles.formRow}>
                <label>Клиент *</label>
                <select
                  value={requirementForm.client_id}
                  onChange={(e) => setRequirementForm({...requirementForm, client_id: e.target.value})}
                  required
                >
                  <option value="">Выберите клиента</option>
                  {clients.map((client: Client) => (
                    <option key={client.id} value={client.id}>{client.name}</option>
                  ))}
                </select>
              </div>
            )}
            <div className={styles.formRow}>
              <label>Название *</label>
              <input
                type="text"
                value={requirementForm.title}
                onChange={(e) => setRequirementForm({...requirementForm, title: e.target.value})}
                required
              />
            </div>
            <div className={styles.formRow}>
              <label>Статус</label>
              <select
                value={requirementForm.status}
                onChange={(e) => setRequirementForm({...requirementForm, status: e.target.value as Requirement['status']})}
              >
                <option value="pending">Ожидание</option>
                <option value="in_progress">В работе</option>
                <option value="completed">Выполнено</option>
                <option value="not_completed">Не выполнено</option>
              </select>
            </div>
            <div className={styles.formRow}>
              <label>Срок выполнения</label>
              <input
                type="date"
                value={requirementForm.deadline}
                onChange={(e) => setRequirementForm({...requirementForm, deadline: e.target.value})}
              />
            </div>
            <div className={styles.formRow}>
              <label>Ответственный</label>
              <input
                type="text"
                value={requirementForm.responsible_person}
                onChange={(e) => setRequirementForm({...requirementForm, responsible_person: e.target.value})}
                placeholder="ФИО"
              />
            </div>
            <div className={styles.formRow}>
              <label>Основание</label>
              <input
                type="text"
                value={requirementForm.basis}
                onChange={(e) => setRequirementForm({...requirementForm, basis: e.target.value})}
                placeholder="КоАП РФ 8.21 ч.1"
              />
            </div>
            <div className={styles.modalActions}>
              <button onClick={() => setShowRequirementForm(false)} className={styles.cancelButton}>
                Отмена
              </button>
              <button onClick={handleSaveRequirement} className={styles.saveButton}>
                Сохранить
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Модальное окно для клиента */}
      {showClientForm && (
        <div className={styles.modal} onClick={() => setShowClientForm(false)}>
          <div className={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <h3>{selectedClient ? 'Редактировать клиента' : 'Добавить клиента'}</h3>
            <div className={styles.formRow}>
              <label>Название *</label>
              <input
                type="text"
                value={clientForm.name}
                onChange={(e) => setClientForm({...clientForm, name: e.target.value})}
                required
              />
            </div>
            <div className={styles.formRow}>
              <label>Категория НВОС *</label>
              <select
                value={clientForm.category_id}
                onChange={(e) => setClientForm({...clientForm, category_id: e.target.value})}
                required
              >
                <option value="">Выберите категорию</option>
                {categories.map(cat => (
                  <option key={cat.id} value={cat.id}>{cat.title}</option>
                ))}
              </select>
            </div>
            <div className={styles.formRow}>
              <label>Источник водопользования</label>
              <select
                onChange={(e) => {
                  const val = e.target.value;
                  setClientForm({
                    ...clientForm,
                    has_well: val === 'well',
                    has_river: val === 'river',
                  });
                }}
                value={clientForm.has_well ? 'well' : clientForm.has_river ? 'river' : ''}
              >
                <option value="">Нет</option>
                <option value="well">Скважина</option>
                <option value="river">Река/озеро</option>
              </select>
            </div>
            <div className={styles.formRow}>
              <label>
                <input
                  type="checkbox"
                  checked={clientForm.has_byproduct}
                  onChange={(e) => setClientForm({...clientForm, has_byproduct: e.target.checked})}
                />
                Есть побочный продукт (животноводство)
              </label>
            </div>
            <div className={styles.formRow}>
              <label>Ответственный</label>
              <input
                type="text"
                value={clientForm.responsible_person}
                onChange={(e) => setClientForm({...clientForm, responsible_person: e.target.value})}
              />
            </div>
            <div className={styles.modalActions}>
              <button onClick={() => setShowClientForm(false)} className={styles.cancelButton}>
                Отмена
              </button>
              <button onClick={handleSaveClient} className={styles.saveButton}>
                Сохранить
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Модальное окно для пользователя */}
      {showUserForm && (
        <div className={styles.modal} onClick={() => setShowUserForm(false)}>
          <div className={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <h3>{selectedUser ? 'Редактировать пользователя' : 'Добавить пользователя'}</h3>
            <div className={styles.formRow}>
              <label>Имя *</label>
              <input
                type="text"
                value={userForm.name}
                onChange={(e) => setUserForm({...userForm, name: e.target.value})}
                required
              />
            </div>
            <div className={styles.formRow}>
              <label>Email *</label>
              <input
                type="email"
                value={userForm.email}
                onChange={(e) => setUserForm({...userForm, email: e.target.value})}
                required
              />
            </div>
            <div className={styles.formRow}>
              <label>Пароль {!selectedUser && '*'}</label>
              <input
                type="password"
                value={userForm.password}
                onChange={(e) => setUserForm({...userForm, password: e.target.value})}
                placeholder={selectedUser ? 'Оставьте пустым, чтобы не менять' : ''}
                required={!selectedUser}
              />
            </div>
            <div className={styles.formRow}>
              <label>Роль *</label>
              <select
                value={userForm.role}
                onChange={(e) => setUserForm({...userForm, role: e.target.value})}
                required
              >
                <option value="admin">Администратор</option>
                <option value="manager">Менеджер</option>
                <option value="specialist">Специалист</option>
                <option value="client">Клиент</option>
              </select>
            </div>
            <div className={styles.formRow}>
              <label>Клиент</label>
              <select
                value={userForm.client_id}
                onChange={(e) => setUserForm({...userForm, client_id: e.target.value})}
              >
                <option value="">Не привязан</option>
                {clients.map(client => (
                  <option key={client.id} value={client.id}>{client.name}</option>
                ))}
              </select>
            </div>
            <div className={styles.modalActions}>
              <button onClick={() => setShowUserForm(false)} className={styles.cancelButton}>
                Отмена
              </button>
              <button onClick={handleSaveUser} className={styles.saveButton}>
                Сохранить
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Модальное окно для НПА */}
      {showNpaForm && (
        <div className={styles.modal} onClick={() => setShowNpaForm(false)}>
          <div className={styles.modalContent} onClick={(e) => e.stopPropagation()}>
            <h3>{selectedNpa ? 'Редактировать НПА' : 'Добавить НПА'}</h3>
            <div className={styles.formRow}>
              <label>Код *</label>
              <input
                type="text"
                value={npaForm.code}
                onChange={(e) => setNpaForm({...npaForm, code: e.target.value})}
                placeholder="ФЗ-89, КоАП РФ 8.2"
                required
              />
            </div>
            <div className={styles.formRow}>
              <label>Название *</label>
              <input
                type="text"
                value={npaForm.title}
                onChange={(e) => setNpaForm({...npaForm, title: e.target.value})}
                required
              />
            </div>
            <div className={styles.formRow}>
              <label>Ссылка</label>
              <input
                type="url"
                value={npaForm.link}
                onChange={(e) => setNpaForm({...npaForm, link: e.target.value})}
                placeholder="https://..."
              />
            </div>
            <div className={styles.formRow}>
              <label>Блок</label>
              <input
                type="text"
                value={npaForm.block}
                onChange={(e) => setNpaForm({...npaForm, block: e.target.value})}
                placeholder="Отходы, Выбросы, Водопользование..."
              />
            </div>
            <div className={styles.modalActions}>
              <button onClick={() => setShowNpaForm(false)} className={styles.cancelButton}>
                Отмена
              </button>
              <button onClick={handleSaveNpa} className={styles.saveButton}>
                Сохранить
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
