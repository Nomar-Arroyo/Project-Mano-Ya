create or replace function public.normalize_venezuelan_mobile(phone text)
returns text
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  digits text;
begin
  if phone is null or btrim(phone) = '' then
    return null;
  end if;

  digits := regexp_replace(phone, '[^0-9]', '', 'g');
  if length(digits) = 11 and left(digits, 1) = '0' then
    digits := substr(digits, 2);
  elsif length(digits) = 12 and left(digits, 2) = '58' then
    digits := substr(digits, 3);
  end if;

  if length(digits) <> 10
     or left(digits, 1) <> '4'
     or substr(digits, 1, 3) not in (
       '412', '414', '416', '422', '424', '426'
     ) then
    raise exception 'El teléfono debe ser un móvil venezolano válido';
  end if;

  return '+58' || digits;
end;
$$;
