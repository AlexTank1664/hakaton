import re
from collections import Counter
import pymorphy3

morph = pymorphy3.MorphAnalyzer()

PAIN_DICTIONARY = {
    "бюрократия_согласование": ["согласование", "тз", "бюрократия", "процесс", "бесконечный", "переделывать"],
    "токсичность_руководство": ["руководитель", "начальник", "токсичный", "микроменеджмент", "крик", "давление"],
    "переработки_нагрузка": ["овертайм", "ночь", "выходной", "дедлайн", "усталость", "нагрузка"],
    "финансы": ["зарплата", "деньги", "премия", "оплата", "бонус", "рынок"]
}

def analyze_raw_text(text: str) -> dict:
    words = re.findall(r"[а-яА-Яa-zA-Z]+", text.lower())
    lemmas = [morph.parse(w)[0].normal_form for w in words]
    counts = Counter(lemmas)

    detected_clusters = {}
    for cluster, keywords in PAIN_DICTIONARY.items():
        score = sum(counts[kw] for kw in keywords if kw in counts)
        if score > 0:
            detected_clusters[cluster] = score

    return {
        "word_count": len(words),
        "cluster_frequencies": detected_clusters
    }