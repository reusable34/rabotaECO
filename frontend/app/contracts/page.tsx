'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { Contract } from '@/lib/types';
import styles from './contracts.module.scss';

export default function ContractsPage() {
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadContracts();
  }, []);

  const loadContracts = async () => {
    try {
      const res = await api.get('/contract');
      // Yii2 REST может возвращать данные в разных форматах
      let conts = Array.isArray(res.data) ? res.data : (res.data?.items || []);
      
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
      
      console.log('✅ Загружено уникальных договоров:', conts.length);
      setContracts(conts);
    } catch (error) {
      console.error('Error loading contracts:', error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className={styles.loading}>Загрузка...</div>;
  }

  return (
    <div className={styles.contracts}>
      <header className={styles.header}>
        <h1>Договоры и акты</h1>
      </header>

      <main className={styles.content}>
        {contracts.length === 0 ? (
          <div className={styles.empty}>Нет договоров</div>
        ) : (
          <div className={styles.contractsList}>
            {contracts.map((contract) => (
              <div key={contract.id} className={styles.contractCard}>
                <div className={styles.contractHeader}>
                  <h3>Договор №{contract.number}</h3>
                  <span className={`${styles.statusBadge} ${
                    contract.status === 'draft' ? styles.statusDraft :
                    contract.status === 'active' ? styles.statusActive :
                    contract.status === 'completed' ? styles.statusCompleted :
                    contract.status === 'cancelled' ? styles.statusCancelled :
                    ''
                  }`}>
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
      </main>
    </div>
  );
}

