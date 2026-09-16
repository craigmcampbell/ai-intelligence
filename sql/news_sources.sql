select * from ai_intel.news_items;

select last_success_at, * from ai_intel.news_sources;


-- Cleanup
delete from ai_intel.news_items;
update ai_intel.news_sources set last_success_at = null;
