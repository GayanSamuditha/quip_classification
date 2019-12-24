function [pred, pred_binary, necr, modification_mark, tumor_im, patch_size, notum_im, tot_width, tot_height] = get_labeled_im(weight_file, mark_file, tot_width, tot_height, mpp)

fprintf('ledebug mark_file: %s\n', mark_file);

% This settings may need tuning
clusterPointsDisPos = 0.003;
clusterPointsDisNeg = 0.003;
timestampDis = 1000;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[w] = textread(weight_file, '%f', 'bufsize', 65536);
lym_w = 1-w(1);
nec_w = w(2);
smh_w = 0.01 + 2 * w(3) * w(3);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[~, ~, m_type, m_width, tses, poly] = textread(mark_file, '%s%s%s%d%s%s', 'delimiter', '\t', 'bufsize', 65536);

%%%%%%%%%%%%%%%%%%%%
pw_20X = 100;
mag = 10.0 / mpp;
patch_size = double(int32(floor(10 * pw_20X * mag / 20))) / 10.0;

x = repmat([1:floor(tot_width / patch_size)], floor(tot_height / patch_size), 1);
x = x(:);
y = repmat([1:floor(tot_height / patch_size)], 1, floor(tot_width / patch_size));
y = y(:);
l = zeros(length(x), 1);
n = zeros(length(x), 1);
%%%%%%%%%%%%%%%%%%%%

iml = zeros(max(x(:)), max(y(:)));
for iter = 1:length(x)
    iml(x(iter), y(iter)) = l(iter);
end
pred = iml;

imn = zeros(max(x(:)), max(y(:)));
for iter = 1:length(x)
    imn(x(iter), y(iter)) = n(iter);
end
necr = imn;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
k = zeros(3, 3);
for i = 1:3
    for j = 1:3
        k(i, j) = 1.0 / (abs(i-2) + abs(j-2) + smh_w);
    end
end
k = k / sum(k(:));
iml = conv2(iml, k, 'same');

pred_binary = uint8((iml >= lym_w) & (imn < nec_w));
modification_mark = ones(max(x(:)), max(y(:)), 'uint8') * 127;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tumor_countor = {};
tumor_lab = {};
time_stamp = '0';
cur_c = [];
all_tum = [];
all_tum_ts = [];
all_not = [];
all_not_ts = [];
cur_lab = 0;
for iter = 1:length(m_type)
    mt = m_type{iter};
    mw = m_width(iter);
    ts = tses{iter};
    po = str2num(poly{iter});
    
    % ignore rows where there are no x&y values
    if length(po) < 1
        disp(['Empty notations: ' num2str(iter)])
        continue;
    end

    if (strcmp(mt, 'LymPos'))
        lab = 1;
        for jter = 1:2:length(po)
            norm_x = po(jter);
            norm_y = po(jter+1);
            modification_mark = marking(modification_mark, ...
                255, mw, norm_x, norm_y, tot_width, tot_height, patch_size);
        end
    elseif (strcmp(mt, 'LymNeg'))
        lab = 0;
        for jter = 1:2:length(po)
            norm_x = po(jter);
            norm_y = po(jter+1);
            modification_mark = marking(modification_mark, ...
                  0, mw, norm_x, norm_y, tot_width, tot_height, patch_size);
        end
    elseif (strcmp(mt, 'TumorPos'))
        if isempty(cur_c) || ...
           (cur_lab == 1 && ...
            (...
            ((cur_c(end-1)-po(1))^2 + (cur_c(end)-po(2))^2)^0.5 < 0.003 || ...
            ((cur_c(1)-cur_c(end-1))^2 + (cur_c(2)-cur_c(end))^2)^0.5 > 0.003 ...
            )...
           )
            cur_c = [cur_c, po];
        else
            tumor_countor{end+1} = cur_c;
            tumor_lab{end+1} = cur_lab;
            cur_c = po;
        end
        all_tum = [all_tum, po];
        all_tum_ts = [all_tum_ts; str2num(ts)*ones(length(po)/2,1)];
        cur_lab = 1;
        time_stamp = ts;
    elseif (strcmp(mt, 'TumorNeg'))
        if isempty(cur_c) || ...
           (cur_lab == 0 && ...
            (...
            ((cur_c(end-1)-po(1))^2 + (cur_c(end)-po(2))^2)^0.5 < 0.003 || ...
            ((cur_c(1)-cur_c(end-1))^2 + (cur_c(2)-cur_c(end))^2)^0.5 > 0.003 ...
            )...
           )
            cur_c = [cur_c, po];
        else
            tumor_countor{end+1} = cur_c;
            tumor_lab{end+1} = cur_lab;
            cur_c = po;
        end
        all_not = [all_not, po];
        all_not_ts = [all_not_ts; str2num(ts)*ones(length(po)/2,1)];
        cur_lab = 0;
        time_stamp = ts;
    end
end
if ~isempty(cur_c)
    tumor_countor{end+1} = cur_c;
    tumor_lab{end+1} = cur_lab;
end

if ~isempty(all_tum)
    %all_tum_mat = [all_tum(1:2:end)', all_tum(2:2:end)', all_tum_ts];
    %tum_clusters = clusterPoints_spatio_temporal(all_tum_mat, clusterPointsDisPos, timestampDis);
    all_tum_mat = [all_tum(1:2:end)', all_tum(2:2:end)'];
    tum_clusters = clusterPoints(all_tum_mat, clusterPointsDisPos);
else
    tum_clusters = [];
end

if ~isempty(all_not)
    %all_not_mat = [all_not(1:2:end)', all_not(2:2:end)', all_not_ts];
    %not_clusters = clusterPoints_spatio_temporal(all_not_mat, clusterPointsDisNeg, timestampDis);
    all_not_mat = [all_not(1:2:end)', all_not(2:2:end)'];
    not_clusters = clusterPoints(all_not_mat, clusterPointsDisNeg);
else
    not_clusters = [];
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%tumor_im = zeros(size(iml,1), size(iml,2), 'uint8');
%for i = 1:length(tumor_countor)
%    tumor_im = tumor_poly_to_mask(tumor_im, tumor_countor{i}, tumor_lab{i});
%end

tumor_im = zeros(size(iml,1), size(iml,2), 'uint8');
notum_im = zeros(size(iml,1), size(iml,2), 'uint8');
for i = 1:length(tum_clusters)
    outline = transpose(tum_clusters{i});
    outline = outline(:);
    tumor_im = tumor_poly_to_mask(tumor_im, outline, 1);
end
for i = 1:length(not_clusters)
    outline = transpose(not_clusters{i});
    outline = outline(:);
    notum_im = tumor_poly_to_mask(notum_im, outline, 1);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [x, y] = defuck(x, y);
if length(x) < 50
    return;
end
x1 = x(5); y1 = y(5); x2 = x(7); y2 = y(7);
dup = 1;
i = 20;
while i < length(x)-6
    if ((abs(x(i)-x1) < 1e-4) && (abs(x(i+4)-x2) < 1e-4) && (abs(y(i)-y1) < 1e-4) && (abs(y(i+4)-y2) < 1e-4))
        dup = dup + 1;
        i = i + 40;
    end
    i = i + 1;
end
if dup > 1
    fprintf('dedup %d\n', dup);
    cut_len = round(length(x)/dup);
    x = x(1:cut_len);
    y = y(1:cut_len);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function im = tumor_poly_to_mask(im, countor, lab)
% poly_x, poly_y are inverted for poly2mask
poly_x = countor(1:2:end);
poly_y = countor(2:2:end);
%[poly_x, poly_y] = defuck(poly_x, poly_y);

if length(poly_x) > 200
    poly_x = poly_x(1:ceil(length(poly_x)/200):end);
    poly_y = poly_y(1:ceil(length(poly_y)/200):end);
end

fprintf('Tumor poly length %d [%d]\n', length(poly_x), lab);

[poly_x, poly_y] = points2contour(poly_x, poly_y, 1, 'cw');
bw = poly2mask(size(im,2)*poly_y, size(im,1)*poly_x, size(im,1), size(im,2));
if lab == 1
    im = uint8((im +  uint8(bw > 0.5)) > 0.5);
else
    im = uint8((im .* uint8(bw < 0.5)) > 0.5);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function im = marking(im, lab, width, norm_x, norm_y, tot_width, tot_height, patch_size)
if width == 1
    im = marking_one_step(im, lab, norm_x, norm_y, tot_width, tot_height, patch_size);
else
    norm_step_x = 1.0 / size(im, 1) / 2.0;
    norm_step_y = 1.0 / size(im, 2) / 2.0;
    for bi = -3:3
        for bj = -3:3
            norm_x_add = norm_x + bi * norm_step_x;
            norm_y_add = norm_y + bj * norm_step_y;
            if norm_x_add < 0 | norm_y_add < 0
                continue;
            end
            
            im = marking_one_step(im, lab, norm_x_add, norm_y_add, tot_width, tot_height, patch_size);
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function im = marking_one_step(im, lab, norm_x, norm_y, tot_width, tot_height, patch_size)
x = ceil(norm_x * tot_width / patch_size);
y = ceil(norm_y * tot_height / patch_size);
if x > 0 & y > 0
    im(x, y) = lab;
else
    sprintf('Warning: index out of bound in get_labeled_im.m/marking_one_step()')
end
